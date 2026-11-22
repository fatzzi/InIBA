"""Absolute URLs for stored media.

`LocalImageStore` returns root-relative paths like `/media/posts/ab12.jpg`; the app needs a full URL, so
responses prefix them with the server's own address. Absolute URLs (a cloud store) pass through unchanged.
"""

from collections.abc import Callable

from fastapi import Request

UrlFn = Callable[[str | None], str | None]


def absolute_url_fn(request: Request) -> UrlFn:
    base = str(request.base_url).rstrip("/")

    def to_url(path: str | None) -> str | None:
        return f"{base}{path}" if path and path.startswith("/") else path

    return to_url
