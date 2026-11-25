"""SQLAlchemy models. Mirrors docs/class-model.md and docs/erd.md; IDs are integers (API doc 1.2)."""

from datetime import date, datetime, timezone

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    JSON,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

REACTION_KINDS = ("heart", "fire", "laugh", "wow", "sad", "clap")


def _now() -> datetime:
    return datetime.now(timezone.utc)


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str | None] = mapped_column(String(120), index=True)
    batch: Mapped[str | None] = mapped_column(String(10), index=True)
    department: Mapped[str | None] = mapped_column(String(80), index=True)
    bio: Mapped[str | None] = mapped_column(String(280))
    profile_photo: Mapped[str | None] = mapped_column(String(500))
    mood_sticker: Mapped[str | None] = mapped_column(String(40))
    mood_set_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    tags: Mapped[list[str]] = mapped_column(JSON, default=list, server_default=text("'[]'"))  # student-written, max 5 (API doc 3.3)
    role: Mapped[str] = mapped_column(String(10), default="student")  # student | admin
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False)
    streak_count: Mapped[int] = mapped_column(Integer, default=0)  # unused: streak is computed from posts
    # SCRUM-70: bumped on logout so every JWT issued before it stops working.
    token_version: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    societies: Mapped[list["Society"]] = relationship(secondary="student_societies", back_populates="members")
    posts: Mapped[list["Post"]] = relationship(back_populates="author")


class Society(Base):
    __tablename__ = "societies"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True)
    members: Mapped[list[Student]] = relationship(secondary="student_societies", back_populates="societies")


class StudentSociety(Base):
    __tablename__ = "student_societies"

    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), primary_key=True)
    society_id: Mapped[int] = mapped_column(ForeignKey("societies.id", ondelete="CASCADE"), primary_key=True)


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class LocationTag(Base):
    __tablename__ = "location_tags"

    id: Mapped[int] = mapped_column(primary_key=True)
    zone_name: Mapped[str] = mapped_column(String(60), unique=True)


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), index=True)
    content: Mapped[str | None] = mapped_column(Text)
    image_front: Mapped[str | None] = mapped_column(String(500))
    image_back: Mapped[str | None] = mapped_column(String(500))
    location_tag_id: Mapped[int | None] = mapped_column(ForeignKey("location_tags.id"), index=True)
    is_moment: Mapped[bool] = mapped_column(Boolean, default=False)
    is_removed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)

    author: Mapped[Student] = relationship(back_populates="posts")
    location_tag: Mapped[LocationTag | None] = relationship()
    reactions: Mapped[list["Reaction"]] = relationship(back_populates="post", cascade="all, delete-orphan")
    comments: Mapped[list["Comment"]] = relationship(back_populates="post", cascade="all, delete-orphan")


class Reaction(Base):
    __tablename__ = "reactions"
    __table_args__ = (UniqueConstraint("post_id", "student_id", name="uq_reaction_post_student"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("posts.id", ondelete="CASCADE"), index=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(10))  # one of REACTION_KINDS
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    post: Mapped[Post] = relationship(back_populates="reactions")


class Comment(Base):
    __tablename__ = "comments"

    id: Mapped[int] = mapped_column(primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("posts.id", ondelete="CASCADE"), index=True)
    author_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"))
    text: Mapped[str] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)

    post: Mapped[Post] = relationship(back_populates="comments")


class Report(Base):
    __tablename__ = "reports"
    __table_args__ = (
        UniqueConstraint("reporter_id", "post_id", name="uq_report_reporter_post"),
        UniqueConstraint("reporter_id", "reported_student_id", name="uq_report_reporter_student"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"))
    post_id: Mapped[int | None] = mapped_column(ForeignKey("posts.id", ondelete="CASCADE"), index=True)
    reported_student_id: Mapped[int | None] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"))
    reason: Mapped[str] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(10), default="open")  # open | ignored | removed
    decided_by: Mapped[int | None] = mapped_column(ForeignKey("students.id"))
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class Highlight(Base):
    __tablename__ = "highlights"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(60))
    cover_url: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class HighlightPost(Base):
    __tablename__ = "highlight_posts"

    highlight_id: Mapped[int] = mapped_column(ForeignKey("highlights.id", ondelete="CASCADE"), primary_key=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("posts.id", ondelete="CASCADE"), primary_key=True)


class SpottedAt(Base):
    __tablename__ = "spotted_at"

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), unique=True)
    location_tag_id: Mapped[int | None] = mapped_column(ForeignKey("location_tags.id"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True)
    platform: Mapped[str] = mapped_column(String(10))  # android | ios
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class MomentWindow(Base):
    """One row per student per day: the random time their IBA Moment opens and the 2-minute close."""

    __tablename__ = "moment_windows"
    __table_args__ = (UniqueConstraint("student_id", "day", name="uq_moment_window_student_day"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"))
    day: Mapped[date] = mapped_column(Date)
    opens_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    closes_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
