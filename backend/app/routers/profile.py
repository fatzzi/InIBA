"""GET/PATCH /profile/{id} (API doc 3.2, 3.3; SCRUM-32)."""

import json

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy.orm import Session
from starlette.datastructures import UploadFile

from app.db import get_db
from app.deps import get_current_student
from app.media_urls import absolute_url_fn
from app.models import Student
from app.pagination import DEFAULT_LIMIT
from app.schemas.profile import ProfileOut, ProfileUpdate, ProfileWithPosts
from app.services import profile as svc
from app.storage import ImageStore, get_image_store

router = APIRouter(prefix="/profile", tags=["profile"])

_LIST_FIELDS = ("societies", "tags")


_url_fn = absolute_url_fn


def _parse_list(values: list[str]) -> list[str]:
    """A multipart list field can be repeated (`tags=a&tags=b`) or one JSON array string."""
    if len(values) == 1 and values[0].strip().startswith("["):
        try:
            parsed = json.loads(values[0])
        except json.JSONDecodeError:
            raise HTTPException(400, "Invalid input: list fields must be a JSON array or repeated values")
        if not isinstance(parsed, list):
            raise HTTPException(400, "Invalid input: list fields must be a JSON array or repeated values")
        return parsed
    return [v for v in values if v != ""]


async def _read_body(request: Request) -> tuple[dict, bytes | None]:
    content_type = request.headers.get("content-type", "")
    if content_type.startswith("multipart/form-data"):
        form = await request.form()
        data: dict = {}
        photo: bytes | None = None
        for key in set(form.keys()):
            values = form.getlist(key)
            if key == "profilePhoto":
                upload = values[0]
                if not isinstance(upload, UploadFile):
                    raise HTTPException(400, "Invalid input: profilePhoto must be a file")
                photo = await upload.read()
            elif key in _LIST_FIELDS:
                data[key] = _parse_list([str(v) for v in values])
            else:
                data[key] = str(values[0])
        return data, photo

    raw = await request.body()
    if not raw:
        return {}, None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(400, "Invalid input: body must be JSON or multipart/form-data")
    if not isinstance(data, dict):
        raise HTTPException(400, "Invalid input: body must be a JSON object")
    return data, None


@router.get("/{student_id}", response_model=ProfileWithPosts, response_model_by_alias=True)
def get_profile(
    student_id: int,
    request: Request,
    offset: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_LIMIT, ge=1),
    _: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
) -> ProfileWithPosts:
    """Any logged-in student can view any profile. Email is never included. `limit` is capped at 50."""
    student = svc.get_student_or_404(db, student_id)
    return svc.build_profile_with_posts(db, student, offset, limit, _url_fn(request))


@router.patch(
    "/{student_id}",
    response_model=ProfileOut,
    response_model_by_alias=True,
    openapi_extra={
        "requestBody": {
            "content": {
                "application/json": {"schema": ProfileUpdate.model_json_schema(by_alias=True)},
                "multipart/form-data": {
                    "schema": {
                        "type": "object",
                        "properties": {
                            "profilePhoto": {"type": "string", "format": "binary"},
                            **ProfileUpdate.model_json_schema(by_alias=True)["properties"],
                        },
                    }
                },
            }
        }
    },
)
async def update_profile(
    student_id: int,
    request: Request,
    me: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
    store: ImageStore = Depends(get_image_store),
) -> ProfileOut:
    """Owner-only edit. Send only the fields that change, as JSON or multipart (with `profilePhoto`)."""
    student = svc.get_student_or_404(db, student_id)
    if student.id != me.id:
        raise HTTPException(403, "You can only edit your own profile")

    data, photo = await _read_body(request)
    try:
        update = ProfileUpdate.model_validate(data)
    except ValidationError as exc:
        raise RequestValidationError(exc.errors())

    svc.apply_update(db, student, update, photo=photo, store=store)
    return svc.build_profile(db, student, _url_fn(request))
