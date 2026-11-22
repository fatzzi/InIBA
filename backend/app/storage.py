"""Image storage behind a small interface.

`LocalImageStore` writes to `backend/media/` and returns a `/media/...` URL served by FastAPI. SCRUM-17 can
swap in a cloud store (Firebase/Cloudinary) by implementing `ImageStore` and changing `get_image_store`.
"""

import uuid
from io import BytesIO
from pathlib import Path
from typing import Protocol

from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError

MEDIA_ROOT = Path(__file__).resolve().parent.parent / "media"
MEDIA_URL = "/media"

PROFILE_PHOTO_MIN_SIDE = 400
SQUARE_TOLERANCE = 0.02  # 1:1 within 2%
MAX_UPLOAD_BYTES = 5 * 1024 * 1024
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


def get_image_store() -> ImageStore:
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
