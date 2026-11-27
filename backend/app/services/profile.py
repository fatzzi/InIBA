"""Profile reads and owner edits (SCRUM-32), and the daily timeline (SCRUM-36)."""

from collections.abc import Callable, Iterable
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Post, Society, Student
from app.pagination import DEFAULT_LIMIT, paginate
from app.storage import ImageStore, get_image_store, validate_profile_photo
from app.schemas.profile import (
    PostPage,
    PostThumb,
    ProfileOut,
    ProfileUpdate,
    ProfileWithPosts,
    TimelineDay,
    TimelinePage,
    TimelinePost,
)

CAMPUS_TZ = ZoneInfo("Asia/Karachi")
EXCERPT_LEN = 60
TIMELINE_DEFAULT_DAYS = 14
TIMELINE_MAX_DAYS = 31

UrlFn = Callable[[str | None], str | None]


def _identity(url: str | None) -> str | None:
    return url


def _as_utc(ts: datetime) -> datetime:
    if ts.tzinfo is None:  # SQLite drops tzinfo; values are stored in UTC
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def _local_day(ts: datetime) -> date:
    return _as_utc(ts).astimezone(CAMPUS_TZ).date()


def streak_from_days(days: Iterable[date], today: date) -> int:
    """Consecutive campus-time days with at least one post, counted back from today.

    If there is no post today but there is one yesterday, count from yesterday: a streak only breaks after
    a fully missed day.
    """
    posted = set(days)
    cursor = today if today in posted else today - timedelta(days=1)
    streak = 0
    while cursor in posted:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def compute_streak(db: Session, student_id: int, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    stamps = db.scalars(
        select(Post.created_at).where(Post.author_id == student_id, Post.is_removed.is_(False))
    ).all()
    return streak_from_days((_local_day(ts) for ts in stamps), _local_day(now))


def get_student_or_404(db: Session, student_id: int) -> Student:
    student = db.get(Student, student_id)
    if student is None or not student.is_verified:
        raise HTTPException(404, "Student not found")
    return student


def build_profile(db: Session, student: Student, url: UrlFn = _identity) -> ProfileOut:
    return ProfileOut(
        student_id=student.id,
        name=student.name,
        batch=student.batch,
        department=student.department,
        profile_photo=url(student.profile_photo),
        bio=student.bio,
        mood_sticker=student.mood_sticker,
        societies=sorted(s.name for s in student.societies),
        streak=compute_streak(db, student.id),
        tags=list(student.tags or []),
    )


def post_grid(
    db: Session, student_id: int, offset: int = 0, limit: int = DEFAULT_LIMIT, url: UrlFn = _identity
) -> PostPage:
    query = (
        select(Post)
        .where(Post.author_id == student_id, Post.is_removed.is_(False))
        .order_by(Post.created_at.desc(), Post.id.desc())
    )
    page = paginate(db, query, offset, limit)
    return PostPage(
        is_more=page["isMore"],
        items=[
            PostThumb(
                post_id=p.id,
                thumbnail=url(p.image_back or p.image_front),
                excerpt=(p.content or "")[:EXCERPT_LEN] or None,
            )
            for p in page["items"]
        ],
    )


def timeline(
    db: Session,
    student_id: int,
    offset: int = 0,
    limit: int = TIMELINE_DEFAULT_DAYS,
    url: UrlFn = _identity,
) -> TimelinePage:
    """Every non-removed post, grouped by campus-time day, newest day and newest post first (API doc 3.4).

    `offset` and `limit` count days, not posts; limit is capped at 31. Posts are grouped in Python rather than SQL
    so the campus time zone works the same on SQLite (tests) and Postgres. Only five small columns are loaded,
    and one student's posts are a small set (about one a day).
    """
    offset = max(offset, 0)
    limit = min(max(limit, 1), TIMELINE_MAX_DAYS)
    rows = db.execute(
        select(Post.id, Post.created_at, Post.content, Post.image_front, Post.image_back)
        .where(Post.author_id == student_id, Post.is_removed.is_(False))
        .order_by(Post.created_at.desc(), Post.id.desc())
    ).all()

    days: dict[date, list[TimelinePost]] = {}
    for post_id, created_at, content, front, back in rows:
        days.setdefault(_local_day(created_at), []).append(
            TimelinePost(
                post_id=post_id,
                thumbnail=url(back or front),
                excerpt=(content or "")[:EXCERPT_LEN] or None,
                timestamp=_as_utc(created_at),
            )
        )
    ordered = list(days.items())  # rows are newest first, so days are too
    return TimelinePage(
        is_more=offset + limit < len(ordered),
        items=[TimelineDay(date=day, posts=posts) for day, posts in ordered[offset : offset + limit]],
    )


def build_profile_with_posts(
    db: Session, student: Student, offset: int, limit: int, url: UrlFn = _identity
) -> ProfileWithPosts:
    base = build_profile(db, student, url)
    return ProfileWithPosts(**base.model_dump(), posts=post_grid(db, student.id, offset, limit, url))


def apply_update(
    db: Session,
    student: Student,
    update: ProfileUpdate,
    photo: bytes | None = None,
    store: ImageStore | None = None,
) -> None:
    """Write only the fields the client sent. Raises 400 for an invalid photo or unknown society names.

    Everything is validated before the photo is written, so a rejected request leaves no file behind.
    """
    sent = update.model_fields_set
    photo_ext = validate_profile_photo(photo) if photo is not None else None
    societies: list[Society] | None = None
    if "societies" in sent:
        names = update.societies or []
        societies = list(db.scalars(select(Society).where(Society.name.in_(names))).all()) if names else []
        missing = sorted(set(names) - {s.name for s in societies})
        if missing:
            raise HTTPException(400, f"Unknown society: {', '.join(missing)}")

    if "mood_sticker" in sent:
        mood = update.mood_sticker or None
        if mood != student.mood_sticker:
            student.mood_sticker = mood
            student.mood_set_at = datetime.now(timezone.utc)
    if "bio" in sent:
        student.bio = update.bio or None
    if "department" in sent:
        student.department = update.department or None
    if "batch" in sent:
        student.batch = update.batch or None
    if "tags" in sent:
        student.tags = list(update.tags or [])
    if societies is not None:
        student.societies = societies
    if photo is not None and photo_ext is not None:
        student.profile_photo = (store or get_image_store()).save(photo, "profile", photo_ext)

    db.commit()
    db.refresh(student)
