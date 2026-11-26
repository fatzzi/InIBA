"""GET /feed (API doc 4.1; SCRUM-40, filters SCRUM-29)."""

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.security import get_current_user
from app.media_urls import absolute_url_fn
from app.models import Student
from app.pagination import DEFAULT_LIMIT
from app.schemas.posts import FeedPage
from app.services import feed as svc

router = APIRouter(prefix="/feed", tags=["feed"])


@router.get("", response_model=FeedPage, response_model_by_alias=True)
def get_feed(
    request: Request,
    zone: int | None = Query(None, description="LocationTag tagId from GET /locations (campus zone)"),
    department: str | None = Query(None, max_length=80, description="Author's department name"),
    society: str | None = Query(None, max_length=80, description="A society the author belongs to"),
    batch: int | None = Query(None, ge=1900, le=2100, description="Author's graduating year"),
    offset: int = Query(0, ge=0),
    limit: int = Query(DEFAULT_LIMIT, ge=1, description="Default 20, capped at 50"),
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FeedPage:
    """Recent posts from verified students, newest first. Filters are optional and stack together (AND).

    An empty `items` list means the app shows its empty state. An unknown zone or a non-numeric batch is 400.
    """
    filters = svc.FeedFilters(zone=zone, department=department, society=society, batch=batch)
    return svc.feed(db, me, offset, limit, absolute_url_fn(request), filters)
