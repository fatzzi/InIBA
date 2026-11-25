"""Daily IBA Moment (SCRUM-42, API doc 4.2): one random window per student per campus day.

Each student gets their own time, so students are not all notified at once (test strategy CONT-05). The row in
`moment_windows` is created the first time it is needed (status check, Moment post, or the push scheduler of SCRUM-43
calling `window_for_today` for each student). Nothing reveals the time before the window opens.
"""

import math
import secrets
from datetime import datetime, time, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.models import MomentWindow, Post, Student
from app.schemas.moments import MomentStatus
from app.services.profile import CAMPUS_TZ


def utc_now() -> datetime:
    """The clock, as a FastAPI dependency so tests can replace it."""
    return datetime.now(timezone.utc)


def _as_utc(ts: datetime) -> datetime:
    if ts.tzinfo is None:  # SQLite drops tzinfo; values are stored in UTC
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def _pick_opening(now: datetime, settings: Settings) -> datetime:
    """Random second in the allowed hours that still leaves room for the whole window.

    If the day is already under way only the time still left is used, so a server started at noon does not pick
    a Moment at 9 am. When the allowed hours are over, the row is simply a window that has passed.
    """
    day = now.astimezone(CAMPUS_TZ).date()
    start = datetime.combine(day, settings.moment_earliest, CAMPUS_TZ).astimezone(timezone.utc)
    end = datetime.combine(day, settings.moment_latest, CAMPUS_TZ).astimezone(timezone.utc)
    last = end - timedelta(seconds=settings.moment_duration_seconds)
    first = now.astimezone(timezone.utc).replace(microsecond=0) + timedelta(seconds=1)
    if start < first <= last:
        start = first
    return start + timedelta(seconds=secrets.randbelow(int((last - start).total_seconds()) + 1))


def window_for_today(db: Session, student: Student, now: datetime) -> MomentWindow:
    """The student's window today, created on first use. Racing requests end up with the same row (it is unique)."""
    day = now.astimezone(CAMPUS_TZ).date()
    query = select(MomentWindow).where(MomentWindow.student_id == student.id, MomentWindow.day == day)
    window = db.scalar(query)
    if window is None:
        settings = get_settings()
        opens_at = _pick_opening(now, settings)
        closes_at = opens_at + timedelta(seconds=settings.moment_duration_seconds)
        try:
            with db.begin_nested():
                db.add(MomentWindow(student_id=student.id, day=day, opens_at=opens_at, closes_at=closes_at))
            db.commit()
        except IntegrityError:
            pass  # someone else created it first
        window = db.scalars(query).one()
    return window


def _posted_today(db: Session, student: Student, now: datetime, *, moments_only: bool) -> bool:
    """Posts removed by moderation still count: a removal does not give a second Moment."""
    day = now.astimezone(CAMPUS_TZ).date()
    start = datetime.combine(day, time.min, CAMPUS_TZ).astimezone(timezone.utc)
    query = select(Post.id).where(
        Post.author_id == student.id, Post.created_at >= start, Post.created_at < start + timedelta(days=1)
    )
    if moments_only:
        query = query.where(Post.is_moment.is_(True))
    return db.scalar(query.limit(1)) is not None


def status(db: Session, student: Student, now: datetime) -> MomentStatus:
    window = window_for_today(db, student, now)
    closes_at = _as_utc(window.closes_at)
    active = _as_utc(window.opens_at) <= now < closes_at
    return MomentStatus(
        active=active,
        seconds_remaining=math.ceil((closes_at - now).total_seconds()) if active else 0,
        already_posted=_posted_today(db, student, now, moments_only=True),
        feed_locked=not _posted_today(db, student, now, moments_only=False),
    )


def require_moment_allowed(db: Session, student: Student, now: datetime) -> None:
    """409 if today's Moment is already posted, 410 outside the window.

    The student row stays locked until the post is committed, so two simultaneous uploads cannot both pass.
    (SQLite ignores the lock.) A refusal releases the lock at once instead of at the end of the request.
    """
    window = window_for_today(db, student, now)
    opens_at, closes_at = _as_utc(window.opens_at), _as_utc(window.closes_at)
    db.execute(select(Student.id).where(Student.id == student.id).with_for_update())
    if _posted_today(db, student, now, moments_only=True):
        refusal = HTTPException(409, "You already posted your IBA Moment today")
    elif now < opens_at:
        refusal = HTTPException(410, "The IBA Moment is not open right now")
    elif now >= closes_at:
        refusal = HTTPException(410, "The IBA Moment window has closed for today")
    else:
        return
    db.rollback()
    raise refusal
