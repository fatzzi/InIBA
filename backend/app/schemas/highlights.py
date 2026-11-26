"""Highlight request/response models (API doc 3.5 - 3.8, SCRUM-37). JSON keys are camelCase."""

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator
from pydantic.alias_generators import to_camel

TITLE_MAX = 30
POSTS_MAX = 30

Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=TITLE_MAX)]
PostIds = Annotated[list[int], Field(min_length=1, max_length=POSTS_MAX)]


class _Camel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


def _dedupe(ids: list[int] | None) -> list[int] | None:
    """Keep the first copy of each id, in order (the first id is the cover)."""
    return None if ids is None else list(dict.fromkeys(ids))


class HighlightCreate(_Camel):
    """POST /highlights body."""

    title: Title
    post_ids: PostIds

    @field_validator("post_ids")
    @classmethod
    def _unique(cls, v: list[int] | None) -> list[int] | None:
        return _dedupe(v)


class HighlightUpdate(_Camel):
    """PATCH /highlights/{id} body. Send only what changes; postIds replaces the whole list."""

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, extra="forbid")

    title: Title | None = None
    post_ids: PostIds | None = None

    @field_validator("post_ids")
    @classmethod
    def _unique(cls, v: list[int] | None) -> list[int] | None:
        return _dedupe(v)


class HighlightPostOut(_Camel):
    post_id: int
    thumbnail: str | None


class HighlightOut(_Camel):
    highlight_id: int
    title: str
    cover_thumbnail: str | None
    posts: list[HighlightPostOut]


class HighlightList(_Camel):
    items: list[HighlightOut]


class MessageOut(_Camel):
    message: str
