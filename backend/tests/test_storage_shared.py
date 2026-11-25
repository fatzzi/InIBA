"""SCRUM-76: images go to a shared Supabase bucket so every teammate's backend sees them."""

import httpx
import pytest
from fastapi import HTTPException

from app import storage
from app.config import Settings
from app.storage import LocalImageStore, SupabaseImageStore


def _store(handler) -> SupabaseImageStore:
    client = httpx.Client(transport=httpx.MockTransport(handler))
    return SupabaseImageStore("https://proj.supabase.co/", "secret-key", "media", client=client)


def test_supabase_upload_returns_public_url():
    seen = {}

    def handler(req: httpx.Request) -> httpx.Response:
        seen["url"] = str(req.url)
        seen["auth"] = req.headers["authorization"]
        seen["type"] = req.headers["content-type"]
        seen["body"] = req.content
        return httpx.Response(200, json={"Key": "media/posts/x.jpg"})

    url = _store(handler).save(b"jpeg-bytes", "posts", "jpg")

    assert seen["url"].startswith("https://proj.supabase.co/storage/v1/object/media/posts/")
    assert seen["auth"] == "Bearer secret-key"
    assert seen["type"] == "image/jpeg"
    assert seen["body"] == b"jpeg-bytes"
    path = seen["url"].split("/storage/v1/object/media/")[1]
    assert url == f"https://proj.supabase.co/storage/v1/object/public/media/{path}"


@pytest.mark.parametrize(
    "handler",
    [
        lambda req: httpx.Response(403, json={"error": "denied"}),
        lambda req: (_ for _ in ()).throw(httpx.ConnectError("down")),
    ],
)
def test_supabase_upload_failure_is_502(handler):
    with pytest.raises(HTTPException) as exc:
        _store(handler).save(b"x", "profile", "png")
    assert exc.value.status_code == 502


def test_get_image_store_picks_from_settings(monkeypatch):
    monkeypatch.setattr(storage, "get_settings", lambda: Settings(image_store="local"))
    assert isinstance(storage.get_image_store(), LocalImageStore)

    monkeypatch.setattr(
        storage,
        "get_settings",
        lambda: Settings(image_store="supabase", supabase_url="https://p.supabase.co", supabase_service_key="k"),
    )
    assert isinstance(storage.get_image_store(), SupabaseImageStore)

        # Blank the keys explicitly: Settings() also reads backend/.env, which may hold real ones.
    monkeypatch.setattr(
        storage, "get_settings", lambda: Settings(image_store="supabase", supabase_url="", supabase_service_key="")
    )
    with pytest.raises(RuntimeError):
        storage.get_image_store()


def _prod(**overrides) -> Settings:
    good = dict(
        environment="production",
        jwt_secret="x" * 40,
        database_url="postgresql+psycopg://u:p@host:5432/db",
        image_store="supabase",
        supabase_url="https://p.supabase.co",
        supabase_service_key="k",
        smtp_host="smtp.example.com",
    )
    return Settings(**{**good, **overrides})


def test_production_settings_ok():
    assert _prod().production_problems() == []


@pytest.mark.parametrize(
    "overrides",
    [
        {"jwt_secret": "change-me"},
        {"database_url": "sqlite:///./x.db"},
        {"image_store": "local"},
        {"supabase_service_key": ""},
        {"smtp_host": ""},
    ],
)
def test_production_refuses_unsafe_settings(overrides):
    assert len(_prod(**overrides).production_problems()) == 1


def test_development_never_blocked():
    assert Settings(environment="development").production_problems() == []
