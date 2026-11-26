"""Highlights: named collections of a student's own posts (API doc 3.5 - 3.8, SCRUM-37)."""

from collections import defaultdict

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.media_urls import UrlFn
from app.models import Highlight, HighlightPost, Post, Student
from app.schemas.highlights import HighlightCreate, HighlightOut, HighlightPostOut, HighlightUpdate


def _identity(url: str | None) -> str | None:
    return url


def _thumb(post: Post) -> str | None:
    """Same picture the profile grid uses: the back camera, else the front one. None for text-only posts."""
    return post.image_back or post.image_front


def get_highlight_or_404(db: Session, highlight_id: int) -> Highlight:
    highlight = db.get(Highlight, highlight_id)
    if highlight is None:
        raise HTTPException(404, "Highlight not found")
    return highlight


def ensure_owner(highlight: Highlight, me: Student) -> None:
    """Owner only, as the API doc says (admins don't edit other students' highlights)."""
    if highlight.owner_id != me.id:
        raise HTTPException(403, "You can only change your own highlights")


def load_own_posts(db: Session, me: Student, post_ids: list[int]) -> list[Post]:
    """Return the posts in the order given. 404 if one doesn't exist (or was removed), 403 if one isn't mine."""
    found = {
        p.id: p
        for p in db.scalars(select(Post).where(Post.id.in_(post_ids), Post.is_removed.is_(False)))
    }
    for pid in post_ids:
        if pid not in found:
            raise HTTPException(404, f"Post {pid} not found")
    for pid in post_ids:
        if found[pid].author_id != me.id:
            raise HTTPException(403, "You can only add your own posts to a highlight")
    return [found[pid] for pid in post_ids]


def _set_posts(db: Session, highlight: Highlight, posts: list[Post]) -> None:
    db.execute(delete(HighlightPost).where(HighlightPost.highlight_id == highlight.id))
    db.add_all(
        HighlightPost(highlight_id=highlight.id, post_id=p.id, position=i) for i, p in enumerate(posts)
    )
    highlight.cover_url = _thumb(posts[0]) if posts else None


def create(db: Session, me: Student, body: HighlightCreate) -> Highlight:
    posts = load_own_posts(db, me, body.post_ids)
    highlight = Highlight(owner_id=me.id, title=body.title)
    db.add(highlight)
    db.flush()  # get highlight.id
    _set_posts(db, highlight, posts)
    db.commit()
    return highlight


def update(db: Session, me: Student, highlight: Highlight, body: HighlightUpdate) -> Highlight:
    ensure_owner(highlight, me)
    # Check the posts before changing anything, so a 403/404 leaves the highlight as it was.
    posts = load_own_posts(db, me, body.post_ids) if body.post_ids is not None else None
    if body.title is not None:
        highlight.title = body.title
    if posts is not None:
        _set_posts(db, highlight, posts)
    db.commit()
    return highlight


def remove(db: Session, me: Student, highlight: Highlight) -> None:
    """Deletes the highlight only; the posts stay on the profile."""
    ensure_owner(highlight, me)
    db.execute(delete(HighlightPost).where(HighlightPost.highlight_id == highlight.id))
    db.delete(highlight)
    db.commit()


def build_many(db: Session, highlights: list[Highlight], url: UrlFn = _identity) -> list[HighlightOut]:
    """Two queries for any number of highlights. Removed posts are left out, so a post taken
    down by moderation disappears from highlights too; the cover is always the first visible post."""
    ids = [h.id for h in highlights]
    posts_by_highlight: dict[int, list[Post]] = defaultdict(list)
    if ids:
        rows = db.execute(
            select(HighlightPost.highlight_id, Post)
            .join(Post, Post.id == HighlightPost.post_id)
            .where(HighlightPost.highlight_id.in_(ids), Post.is_removed.is_(False))
            .order_by(HighlightPost.highlight_id, HighlightPost.position, Post.id)
        ).all()
        for highlight_id, post in rows:
            posts_by_highlight[highlight_id].append(post)

    out = []
    for h in highlights:
        posts = posts_by_highlight[h.id]
        out.append(
            HighlightOut(
                highlight_id=h.id,
                title=h.title,
                cover_thumbnail=url(_thumb(posts[0])) if posts else None,
                posts=[HighlightPostOut(post_id=p.id, thumbnail=url(_thumb(p))) for p in posts],
            )
        )
    return out


def build_one(db: Session, highlight: Highlight, url: UrlFn = _identity) -> HighlightOut:
    return build_many(db, [highlight], url)[0]


def list_for_student(db: Session, student_id: int, url: UrlFn = _identity) -> list[HighlightOut]:
    if db.get(Student, student_id) is None:
        raise HTTPException(404, "Student not found")
    highlights = list(
        db.scalars(
            select(Highlight)
            .where(Highlight.owner_id == student_id)
            .order_by(Highlight.created_at, Highlight.id)
        )
    )
    return build_many(db, highlights, url)
