"""Profile request/response models (API doc 3.2, 3.3). JSON keys are camelCase; email is never part of them."""

from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator
from pydantic.alias_generators import to_camel

BIO_MAX = 150
TAGS_MAX = 5
TAG_MAX_LEN = 20

Tag = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=TAG_MAX_LEN)]
SocietyName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]


class _Camel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class PostThumb(_Camel):
    post_id: int
    thumbnail: str | None
    excerpt: str | None


class PostPage(_Camel):
    is_more: bool
    items: list[PostThumb]


class TimelinePost(PostThumb):
    timestamp: datetime


class TimelineDay(_Camel):
    date: date
    posts: list[TimelinePost]


class TimelinePage(_Camel):
    """GET /profile/{id}/timeline (API doc 3.4): one item per day; offset and limit count days."""

    is_more: bool
    items: list[TimelineDay]


class ProfileOut(_Camel):
    student_id: int
    name: str | None
    batch: str | None
    department: str | None
    profile_photo: str | None
    bio: str | None
    mood_sticker: str | None
    societies: list[str]
    streak: int
    tags: list[str]


class ProfileWithPosts(ProfileOut):
    posts: PostPage


class ProfileUpdate(_Camel):
    """PATCH body. Every field is optional; only the fields sent are changed.

    `streak` is computed, so sending it (or any other unknown field) is a 400.
    """

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, extra="forbid")

    mood_sticker: Annotated[str, StringConstraints(strip_whitespace=True, max_length=40)] | None = None
    bio: Annotated[str, StringConstraints(max_length=BIO_MAX)] | None = None
    department: Annotated[str, StringConstraints(strip_whitespace=True, max_length=80)] | None = None
    batch: Annotated[str, StringConstraints(strip_whitespace=True, max_length=10)] | None = None
    societies: list[SocietyName] | None = None
    tags: Annotated[list[Tag], Field(max_length=TAGS_MAX)] | None = None

    @field_validator("societies", "tags")
    @classmethod
    def _dedupe(cls, v: list[str] | None) -> list[str] | None:
        return None if v is None else list(dict.fromkeys(v))
