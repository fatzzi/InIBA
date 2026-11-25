"""Image storage behind a small interface.

`LocalImageStore` writes to `backend/media/` and returns a `/media/...` URL served by FastAPI; only the machine
running that backend has the files. `SupabaseImageStore` uploads to a shared bucket so the whole team sees every
image. `IMAGE_STORE` in `.env` picks one (see docs/environment.md, "Shared team database").
"""

import uuid
from io import BytesIO
from pathlib import Path
from typing import Protocol

import httpx
from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError

from app.config import get_settings

MEDIA_ROOT = Path(__file__).resolve().parent.parent / "media"
MEDIA_URL = "/media"

PROFILE_PHOTO_MIN_SIDE = 400
SQUARE_TOLERANCE = 0.02  # 1:1 within 2%
MAX_UPLOAD_BYTES = 5 * 1024 * 1024
POST_IMAGE_MAX_BYTES = 10 * 1024 * 1024
_FORMATS = {"JPEG": "jpg", "PNG": "png"}


class ImageStore(Protocol):
    def save(self, data: bytes, folder: str, ext: str) -> str:
        """Store the bytes and return a URL (absolute or root-relative) for them."""


class LocalImageStore:
    def __init__(self, root: Path = MEDIA_ROOT, base_url: str = MEDIA_URL) -> None:
        self.root = root
        self.base_url = base_url

    def save(self, data: bytes, folder: str, ext: str) -> str:
        target_dir = self.root / folder
        target_dir.mkdir(parents=True, exist_ok=True)
        name = f"{uuid.uuid4().hex}.{ext}"
        (target_dir / name).write_bytes(data)
        return f"{self.base_url}/{folder}/{name}"


_CONTENT_TYPES = {"jpg": "image/jpeg", "png": "image/png"}


class SupabaseImageStore:
    """Uploads to a public Supabase Storage bucket and returns its public URL (SCRUM-76).

    Every teammate's backend points at the same bucket, so a photo uploaded through one backend is visible
    to all of them. Uses the Storage REST API directly, so no extra SDK is needed.
    """

    def __init__(self, url: str, service_key: str, bucket: str, client: httpx.Client | None = None) -> None:
        self.url = url.rstrip("/")
        self.bucket = bucket
        self._headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
        self._client = client or httpx.Client(timeout=20)

    def save(self, data: bytes, folder: str, ext: str) -> str:
        path = f"{folder}/{uuid.uuid4().hex}.{ext}"
        headers = {**self._headers, "Content-Type": _CONTENT_TYPES.get(ext, "application/octet-stream")}
        try:
            res = self._client.post(f"{self.url}/storage/v1/object/{self.bucket}/{path}", content=data, headers=headers)
        except httpx.HTTPError:
            raise HTTPException(502, "Could not upload the image. Try again.")
        if res.status_code >= 300:
            raise HTTPException(502, "Could not upload the image. Try again.")
        return f"{self.url}/storage/v1/object/public/{self.bucket}/{path}"


def get_image_store() -> ImageStore:
    settings = get_settings()
    if settings.image_store == "supabase":
        if not settings.supabase_url or not settings.supabase_service_key:
            raise RuntimeError("IMAGE_STORE=supabase needs SUPABASE_URL and SUPABASE_SERVICE_KEY in backend/.env")
        return SupabaseImageStore(settings.supabase_url, settings.supabase_service_key, settings.supabase_bucket)
    return LocalImageStore()


def validate_profile_photo(data: bytes) -> str:
    """Return the file extension for a valid profile photo, or raise 400.

    Rules (API doc 3.3): JPEG or PNG, square (1:1), at least 400x400.
    """
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(400, "Profile photo must be 5 MB or smaller")
    try:
        with Image.open(BytesIO(data)) as img:
            fmt, (w, h) = img.format, img.size
            img.verify()
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(400, "Profile photo must be a JPEG or PNG image")
    if fmt not in _FORMATS:
        raise HTTPException(400, "Profile photo must be a JPEG or PNG image")
    if min(w, h) < PROFILE_PHOTO_MIN_SIDE:
        raise HTTPException(400, f"Profile photo must be at least {PROFILE_PHOTO_MIN_SIDE}x{PROFILE_PHOTO_MIN_SIDE}")
    if abs(w - h) > SQUARE_TOLERANCE * max(w, h):
        raise HTTPException(400, "Profile photo must be square (1:1)")
    return _FORMATS[fmt]


def validate_post_image(data: bytes, field: str) -> str:
    """Return the file extension for a valid post image, or raise 400.

    Rules (API doc 4.3): JPEG or PNG, at most 10 MB. Any size or shape, since camera photos vary.
    """
    if len(data) > POST_IMAGE_MAX_BYTES:
        raise HTTPException(400, f"{field} must be 10 MB or smaller")
    try:
        with Image.open(BytesIO(data)) as img:
            fmt = img.format
            img.verify()
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(400, f"{field} must be a JPEG or PNG image")
    if fmt not in _FORMATS:
        raise HTTPException(400, f"{field} must be a JPEG or PNG image")
    return _FORMATS[fmt]
