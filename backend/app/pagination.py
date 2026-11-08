"""Pagination helper: list endpoints take offset/limit and return {isMore, items[]} (API doc 1.2)."""

from typing import Any

from sqlalchemy import Select
from sqlalchemy.orm import Session

DEFAULT_LIMIT = 20
MAX_LIMIT = 50


def paginate(db: Session, query: Select, offset: int = 0, limit: int = DEFAULT_LIMIT) -> dict[str, Any]:
    offset = max(offset, 0)
    limit = min(max(limit, 1), MAX_LIMIT)
    rows = db.scalars(query.offset(offset).limit(limit + 1)).all()
    return {"isMore": len(rows) > limit, "items": rows[:limit]}
