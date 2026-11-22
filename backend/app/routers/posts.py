"""POST /posts, GET /posts/{postId}, DELETE /posts/{postId} (API doc 4.3-4.5; SCRUM-39)."""

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.security import get_current_user
from app.media_urls import absolute_url_fn
from app.models import Student
from app.schemas.posts import Message, PostOut
from app.services import posts as svc
from app.storage import ImageStore, get_image_store

router = APIRouter(prefix="/posts", tags=["posts"])


async def _read(upload: UploadFile | None) -> bytes | None:
    if upload is None:
        return None
    data = await upload.read()
    return data or None  # an empty file field means "no image"


@router.post("", response_model=PostOut, response_model_by_alias=True, status_code=status.HTTP_201_CREATED)
async def create_post(
    request: Request,
    content: str | None = Form(None, description="Caption, or the text of a text post. Max 300 chars"),
    imageBack: UploadFile = File(None, description="Back camera photo (JPEG/PNG, max 10 MB)"),
    imageFront: UploadFile = File(None, description="Front camera photo, only together with imageBack"),
    locationTagId: int | None = Form(None, description="Optional campus zone (tagId). Empty or 0 means no zone"),
    isMoment: bool = Form(False, description="true when posted from the IBA Moment prompt"),
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
    store: ImageStore = Depends(get_image_store),
) -> PostOut:
    """Publish a text post or a photo post (multipart/form-data). A new post has zero reactions and comments."""
    if request.headers.get("content-type", "").startswith("application/json"):
        raise HTTPException(400, "Send posts as multipart/form-data, not JSON")
    post = svc.create_post(
        db,
        me,
        store,
        content=content,
        image_back=await _read(imageBack),
        image_front=await _read(imageFront),
        location_tag_id=locationTagId or None,  # the docs page sends 0 for an untouched field; ids start at 1
        is_moment=isMoment,
    )
    return svc.to_out(db, post, me, absolute_url_fn(request))


@router.get("/{post_id}", response_model=PostOut, response_model_by_alias=True)
def get_post(
    post_id: int,
    request: Request,
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PostOut:
    """Full view of one post. Removed posts are 404."""
    post = svc.get_post_or_404(db, post_id)
    return svc.to_out(db, post, me, absolute_url_fn(request))


@router.delete("/{post_id}", response_model=Message)
def delete_post(
    post_id: int,
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Message:
    """Author only. Its reactions and comments are deleted with it."""
    post = svc.get_post_or_404(db, post_id, include_removed=True)
    svc.delete_post(db, post, me)
    return Message(message="Post deleted")
