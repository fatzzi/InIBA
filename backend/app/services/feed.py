"""Main feed (SCRUM-40, API doc 4.1): recent non-removed posts from verified students, newest first.

This is the base endpoint. Still to come in their own stories:
- filters `zone`, `department`, `society`, `batch` (SCRUM-29), which add `where` clauses to `feed_query`;
- the "post something today to unlock the feed" 403 (SCRUM-48).
"""

from sqlalchemy import Select, select
from sqlalchemy.orm import Session, joinedload

from app.media_urls import UrlFn
from app.models import Post, Student
from app.pagination import DEFAULT_LIMIT, paginate
from app.schemas.posts import FeedPage
from app.services.posts import _identity, to_out_many


def feed_query() -> Select:
    return (
        select(Post)
        .join(Post.author)
        .where(Post.is_removed.is_(False), Student.is_verified.is_(True))
        .options(joinedload(Post.author), joinedload(Post.location_tag))
        .order_by(Post.created_at.desc(), Post.id.desc())
    )


def feed(
    db: Session, viewer: Student, offset: int = 0, limit: int = DEFAULT_LIMIT, url: UrlFn = _identity
) -> FeedPage:
    page = paginate(db, feed_query(), offset, limit)  # caps limit at 50
    return FeedPage(is_more=page["isMore"], items=to_out_many(db, list(page["items"]), viewer, url))
