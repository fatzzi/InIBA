"""GET /feed (API doc 4.1; SCRUM-40)."""

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_student
from app.media_urls import absolute_url_fn
from app.models import Student
from app.pagination import DEFAULT_LIMIT
from app.schemas.posts import FeedPage
from app.services import feed as svc

router = APIRouter(prefix="/feed", tags=["feed"])


@router.get("", response_model=FeedPage, response_model_by_alias=True)
def get_feed(
    request: Request,
    offset: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_LIMIT, ge=1, description="Default 20, capped at 50"),
    me: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
) -> FeedPage:
    """Recent posts from verified students, newest first. An empty `items` list means the app shows its empty state."""
    return svc.feed(db, me, offset, limit, absolute_url_fn(request))
