"""Highlights on a profile (API doc 3.5 - 3.8, SCRUM-37).

GET    /profile/{id}/highlights   any logged-in student
POST   /highlights                creates one owned by the caller
PATCH  /highlights/{highlightId}  owner only; postIds replaces the whole list
DELETE /highlights/{highlightId}  owner only; the posts themselves are kept
"""

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.media_urls import absolute_url_fn
from app.models import Student
from app.schemas.highlights import HighlightCreate, HighlightList, HighlightOut, HighlightUpdate, MessageOut
from app.security import get_current_user
from app.services import highlights as svc

router = APIRouter(tags=["highlights"])


@router.get("/profile/{student_id}/highlights", response_model=HighlightList, response_model_by_alias=True)
def list_highlights(
    student_id: int,
    request: Request,
    _: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HighlightList:
    return HighlightList(items=svc.list_for_student(db, student_id, absolute_url_fn(request)))


@router.post(
    "/highlights",
    status_code=status.HTTP_201_CREATED,
    response_model=HighlightOut,
    response_model_by_alias=True,
)
def create_highlight(
    body: HighlightCreate,
    request: Request,
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HighlightOut:
    """Every post in postIds must be one of the caller's own posts; the first one is the cover."""
    highlight = svc.create(db, me, body)
    return svc.build_one(db, highlight, absolute_url_fn(request))


@router.patch("/highlights/{highlight_id}", response_model=HighlightOut, response_model_by_alias=True)
def update_highlight(
    highlight_id: int,
    body: HighlightUpdate,
    request: Request,
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HighlightOut:
    """Send only what changes. postIds replaces the whole list (use it to add timeline posts)."""
    highlight = svc.get_highlight_or_404(db, highlight_id)
    svc.update(db, me, highlight, body)
    return svc.build_one(db, highlight, absolute_url_fn(request))


@router.delete("/highlights/{highlight_id}", response_model=MessageOut)
def delete_highlight(
    highlight_id: int,
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageOut:
    highlight = svc.get_highlight_or_404(db, highlight_id)
    svc.remove(db, me, highlight)
    return MessageOut(message="Highlight deleted")
