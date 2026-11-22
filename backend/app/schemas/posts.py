"""Post response models (API doc 4.3, 4.4, data model "Post"). JSON keys are camelCase."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel

CONTENT_MAX = 300


class _Camel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class Author(_Camel):
    student_id: int
    name: str | None
    profile_photo: str | None


class LocationTagOut(_Camel):
    tag_id: int
    zone_name: str


class PostOut(_Camel):
    post_id: int
    student_id: int
    author: Author
    content: str | None
    image_back: str | None
    image_front: str | None
    timestamp: datetime
    is_removed: bool
    is_moment: bool
    location_tag: LocationTagOut | None
    reaction_count: int
    comment_count: int
    your_reaction: str | None


class Message(BaseModel):
    message: str
