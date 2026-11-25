"""GET /moments/current response (API doc 4.2). JSON keys are camelCase."""

from app.schemas.posts import _Camel


class MomentStatus(_Camel):
    active: bool
    seconds_remaining: int
    already_posted: bool
    feed_locked: bool
