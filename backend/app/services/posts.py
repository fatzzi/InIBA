"""Create, view and delete posts (SCRUM-39, API doc 4.3-4.5).

Not here yet, by design: the IBA Moment window and one-Moment-per-day rules (409/410) come with the Moment
scheduler (SCRUM-42), and image moderation (422) with the moderation epic. `isMoment` is stored as sent.
"""

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.media_urls import UrlFn
from app.models import Comment, HighlightPost, LocationTag, Post, Reaction, Report, Student
from app.schemas.posts import CONTENT_MAX, Author, LocationTagOut, PostOut
from app.storage import ImageStore, validate_post_image


def _identity(url: str | None) -> str | None:
    return url


def _as_utc(ts: datetime) -> datetime:
    if ts.tzinfo is None:  # SQLite drops tzinfo; values are stored in UTC
        return ts.replace(tzinfo=timezone.utc)
    return ts.astimezone(timezone.utc)


def create_post(
    db: Session,
    author: Student,
    store: ImageStore,
    *,
    content: str | None,
    image_back: bytes | None,
    image_front: bytes | None,
    location_tag_id: int | None,
    is_moment: bool,
) -> Post:
    """Validate everything first, then write images, then the row, so a rejected post leaves no files."""
    text = (content or "").strip() or None
    if text is not None and len(text) > CONTENT_MAX:
        raise HTTPException(400, f"content must be {CONTENT_MAX} characters or fewer")
    if image_front is not None and image_back is None:
        raise HTTPException(400, "imageFront can only be sent together with imageBack")
    if text is None and image_back is None:
        raise HTTPException(400, "A post needs content or an image")

    back_ext = validate_post_image(image_back, "imageBack") if image_back is not None else None
    front_ext = validate_post_image(image_front, "imageFront") if image_front is not None else None
    if location_tag_id is not None and db.get(LocationTag, location_tag_id) is None:
        raise HTTPException(400, "Unknown locationTagId")

    post = Post(
        author_id=author.id,
        content=text,
        location_tag_id=location_tag_id,
        is_moment=is_moment,
        image_back=store.save(image_back, "posts", back_ext) if image_back and back_ext else None,
        image_front=store.save(image_front, "posts", front_ext) if image_front and front_ext else None,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


def get_post_or_404(db: Session, post_id: int, *, include_removed: bool = False) -> Post:
    post = db.get(Post, post_id)
    if post is None or (post.is_removed and not include_removed):
        raise HTTPException(404, "Post not found")
    return post


def to_out(db: Session, post: Post, viewer: Student, url: UrlFn = _identity) -> PostOut:
    reactions = db.scalar(select(func.count()).select_from(Reaction).where(Reaction.post_id == post.id)) or 0
    comments = db.scalar(select(func.count()).select_from(Comment).where(Comment.post_id == post.id)) or 0
    mine = db.scalar(select(Reaction.kind).where(Reaction.post_id == post.id, Reaction.student_id == viewer.id))
    author = post.author
    tag = post.location_tag
    return PostOut(
        post_id=post.id,
        student_id=author.id,
        author=Author(student_id=author.id, name=author.name, profile_photo=url(author.profile_photo)),
        content=post.content,
        image_back=url(post.image_back),
        image_front=url(post.image_front),
        timestamp=_as_utc(post.created_at),
        is_removed=post.is_removed,
        is_moment=post.is_moment,
        location_tag=LocationTagOut(tag_id=tag.id, zone_name=tag.zone_name) if tag else None,
        reaction_count=reactions,
        comment_count=comments,
        your_reaction=mine,
    )


def delete_post(db: Session, post: Post, me: Student) -> None:
    """Author only. Reactions, comments, reports and highlight entries go with it.

    The database cascades these on Postgres; they are deleted explicitly too so SQLite (tests, local dev)
    behaves the same. Image files stay in storage for now: the store has no delete yet (SCRUM-17).
    """
    if post.author_id != me.id:
        raise HTTPException(403, "You can only delete your own posts")
    db.execute(delete(HighlightPost).where(HighlightPost.post_id == post.id))
    db.execute(delete(Report).where(Report.post_id == post.id))
    db.delete(post)  # ORM cascade removes reactions and comments
    db.commit()
