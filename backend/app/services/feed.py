"""Main feed (SCRUM-40, API doc 4.1): recent non-removed posts from verified students, newest first.

Optional filters (SCRUM-29) stack together with AND: `zone` matches the post's location tag; `department`,
`society` and `batch` match the author's profile. Department and society names ignore case and surrounding spaces.

Still to come in its own story: the "post something today to unlock the feed" 403 (SCRUM-48).
"""

from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy import Select, exists, func, select
from sqlalchemy.orm import Session, joinedload

from app.media_urls import UrlFn
from app.models import LocationTag, Post, Society, Student, StudentSociety
from app.pagination import DEFAULT_LIMIT, paginate
from app.schemas.posts import FeedPage
from app.services.posts import _identity, to_out_many


@dataclass(frozen=True)
class FeedFilters:
    zone: int | None = None
    department: str | None = None
    society: str | None = None
    batch: int | None = None


NO_FILTERS = FeedFilters()


def _clean(value: str | None) -> str | None:
    """Blank text filters count as not given, so an app that sends `department=` still gets the whole feed."""
    return (value or "").strip().lower() or None


def feed_query(filters: FeedFilters = NO_FILTERS) -> Select:
    query = (
        select(Post)
        .join(Post.author)
        .where(Post.is_removed.is_(False), Student.is_verified.is_(True))
        .options(joinedload(Post.author), joinedload(Post.location_tag))
        .order_by(Post.created_at.desc(), Post.id.desc())
    )
    if filters.zone is not None:
        query = query.where(Post.location_tag_id == filters.zone)
    if department := _clean(filters.department):
        query = query.where(func.lower(func.trim(Student.department)) == department)
    if society := _clean(filters.society):
        query = query.where(
            exists().where(
                StudentSociety.student_id == Student.id,
                StudentSociety.society_id == Society.id,
                func.lower(func.trim(Society.name)) == society,
            )
        )
    if filters.batch is not None:
        query = query.where(func.trim(Student.batch) == str(filters.batch))
    return query


def check_filters(db: Session, filters: FeedFilters) -> None:
    """400 for a zone id that is not one of the preset zones (test strategy FILT-04)."""
    if filters.zone is not None and db.get(LocationTag, filters.zone) is None:
        raise HTTPException(400, "Unknown zone")


def feed(
    db: Session,
    viewer: Student,
    offset: int = 0,
    limit: int = DEFAULT_LIMIT,
    url: UrlFn = _identity,
    filters: FeedFilters = NO_FILTERS,
) -> FeedPage:
    check_filters(db, filters)
    page = paginate(db, feed_query(filters), offset, limit)  # caps limit at 50
    return FeedPage(is_more=page["isMore"], items=to_out_many(db, list(page["items"]), viewer, url))
