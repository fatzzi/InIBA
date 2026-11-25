"""SCRUM-39: POST /posts, GET /posts/{id}, DELETE /posts/{id}."""

from datetime import datetime, timedelta, timezone
from io import BytesIO

import pytest
from PIL import Image
from sqlalchemy import select

from app.security import get_current_user
from app.main import app
from app.models import Comment, Highlight, HighlightPost, LocationTag, MomentWindow, Post, Reaction, Report, Student
from app.services.profile import CAMPUS_TZ
from app.storage import LocalImageStore, get_image_store


@pytest.fixture()
def people(db_session):
    a = Student(email="sara.a@khi.iba.edu.pk", password_hash="x", name="Sara A.", is_verified=True,
                profile_photo="/media/profile/sara.jpg")
    b = Student(email="hamza.k@khi.iba.edu.pk", password_hash="x", name="Hamza K.", is_verified=True)
    library = LocationTag(zone_name="Library")
    db_session.add_all([a, b, library])
    db_session.commit()
    return a, b, library


@pytest.fixture()
def media(tmp_path):
    store = LocalImageStore(root=tmp_path, base_url="/media")
    app.dependency_overrides[get_image_store] = lambda: store
    return tmp_path


@pytest.fixture()
def login(client):
    def as_(student: Student):
        app.dependency_overrides[get_current_user] = lambda: student
        return client

    return as_


def _img(fmt: str = "JPEG", size=(1200, 900)) -> bytes:
    buf = BytesIO()
    Image.new("RGB", size, (30, 90, 200)).save(buf, fmt)
    return buf.getvalue()


def _files(back: bytes | None = None, front: bytes | None = None) -> dict:
    files = {}
    if back is not None:
        files["imageBack"] = ("back.jpg", back, "image/jpeg")
    if front is not None:
        files["imageFront"] = ("front.jpg", front, "image/jpeg")
    return files


# ---------- POST /posts ----------


def test_text_post(login, people, media):
    a, _, _ = people
    before = datetime.now(timezone.utc) - timedelta(seconds=1)
    res = login(a).post("/posts", data={"content": "  Anyone up for chai at the café?  "})
    assert res.status_code == 201
    body = res.json()
    assert set(body) == {
        "postId", "studentId", "author", "content", "imageBack", "imageFront", "timestamp", "isRemoved",
        "isMoment", "locationTag", "reactionCount", "commentCount", "yourReaction",
    }
    assert body["content"] == "Anyone up for chai at the café?"  # trimmed
    assert body["imageBack"] is None and body["imageFront"] is None
    assert body["studentId"] == a.id
    assert body["author"] == {
        "studentId": a.id, "name": "Sara A.", "profilePhoto": "http://testserver/media/profile/sara.jpg",
    }
    assert body["reactionCount"] == 0 and body["commentCount"] == 0 and body["yourReaction"] is None
    assert body["isMoment"] is False and body["isRemoved"] is False and body["locationTag"] is None
    assert body["timestamp"].endswith("Z")
    assert before <= datetime.fromisoformat(body["timestamp"]) <= datetime.now(timezone.utc)


def test_dual_image_post_with_zone_and_moment(login, people, media, db_session):
    a, _, library = people
    now = datetime.now(timezone.utc)
    db_session.add(MomentWindow(
        day=now.astimezone(CAMPUS_TZ).date(), opens_at=now - timedelta(seconds=60), closes_at=now + timedelta(seconds=60),
    ))
    db_session.commit()
    res = login(a).post(
        "/posts",
        data={"content": "Library grind", "locationTagId": str(library.id), "isMoment": "true"},
        files=_files(_img("JPEG"), _img("PNG", (600, 800))),
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["imageBack"].startswith("http://testserver/media/posts/") and body["imageBack"].endswith(".jpg")
    assert body["imageFront"].endswith(".png")
    assert body["locationTag"] == {"tagId": library.id, "zoneName": "Library"}
    assert body["isMoment"] is True
    assert len(list((media / "posts").iterdir())) == 2  # both files written

    saved = db_session.get(Post, body["postId"])
    assert saved.author_id == a.id and saved.image_back.startswith("/media/posts/")


def test_photo_post_without_caption(login, people, media):
    a, _, _ = people
    res = login(a).post("/posts", files=_files(_img()))
    assert res.status_code == 201
    assert res.json()["content"] is None and res.json()["imageFront"] is None


@pytest.mark.parametrize(
    "data, files, message",
    [
        ({}, {}, "needs content or an image"),
        ({"content": "   "}, {}, "needs content or an image"),
        ({"content": "x" * 301}, {}, "300 characters"),
        ({}, {"imageBack": ("b.jpg", b"", "image/jpeg")}, "needs content or an image"),  # empty file = none
        ({"content": "hi"}, {"imageBack": ("a.gif", b"GIF89a....", "image/gif")}, "JPEG or PNG"),
        ({"content": "hi", "locationTagId": "999"}, {}, "Unknown locationTagId"),
        ({"content": "hi", "locationTagId": "abc"}, {}, "Invalid input"),
    ],
)
def test_bad_posts_are_400(login, people, media, data, files, message):
    a, _, _ = people
    res = login(a).post("/posts", data=data, files=files or None)
    assert res.status_code == 400
    assert res.json()["code"] == 400 and message in res.json()["message"]
    assert not (media / "posts").exists()  # nothing written for a rejected post


def test_front_without_back_is_400(login, people, media):
    a, _, _ = people
    res = login(a).post("/posts", data={"content": "hi"}, files=_files(front=_img()))
    assert res.status_code == 400 and "together with imageBack" in res.json()["message"]
    assert not (media / "posts").exists()


def test_bad_front_image_writes_no_back_image(login, people, media):
    a, _, _ = people
    res = login(a).post("/posts", files={
        "imageBack": ("b.jpg", _img(), "image/jpeg"),
        "imageFront": ("f.jpg", b"not an image", "image/jpeg"),
    })
    assert res.status_code == 400 and "imageFront" in res.json()["message"]
    assert not (media / "posts").exists()


def test_image_over_10_mb_is_400(login, people, media, monkeypatch):
    import app.storage as storage

    monkeypatch.setattr(storage, "POST_IMAGE_MAX_BYTES", 1000)
    a, _, _ = people
    res = login(a).post("/posts", files=_files(_img()))
    assert res.status_code == 400 and "10 MB" in res.json()["message"]


def test_swagger_style_form_with_empty_files_and_zone_0(login, people, media):
    """What the /docs page sends when only the caption is filled in."""
    a, _, _ = people
    res = login(a).post("/posts", data={
        "content": "from the docs page", "imageBack": "", "imageFront": "", "locationTagId": "0", "isMoment": "false",
    })
    assert res.status_code == 201, res.text
    assert res.json()["locationTag"] is None and res.json()["imageBack"] is None


def test_json_body_gets_a_clear_400(login, people, media):
    a, _, _ = people
    res = login(a).post("/posts", json={"content": "hi"})
    assert res.status_code == 400 and "multipart/form-data" in res.json()["message"]


def test_300_characters_is_allowed(login, people, media):
    a, _, _ = people
    assert login(a).post("/posts", data={"content": "x" * 300}).status_code == 201


def test_new_post_shows_on_profile_grid(login, people, media):
    a, _, _ = people
    api = login(a)
    post_id = api.post("/posts", data={"content": "fresh"}).json()["postId"]
    grid = api.get(f"/profile/{a.id}").json()["posts"]["items"]
    assert grid[0]["postId"] == post_id and grid[0]["excerpt"] == "fresh"


# ---------- GET /posts/{id} ----------


def test_get_post_with_counts_and_my_reaction(login, people, media, db_session):
    a, b, _ = people
    post_id = login(a).post("/posts", data={"content": "Library grind"}).json()["postId"]
    db_session.add_all([
        Reaction(post_id=post_id, student_id=a.id, kind="heart"),
        Reaction(post_id=post_id, student_id=b.id, kind="fire"),
        Comment(post_id=post_id, author_id=b.id, text="same"),
    ])
    db_session.commit()

    as_b = login(b).get(f"/posts/{post_id}")
    assert as_b.status_code == 200
    body = as_b.json()
    assert body["reactionCount"] == 2 and body["commentCount"] == 1
    assert body["yourReaction"] == "fire"
    assert body["author"]["studentId"] == a.id  # the author, not the viewer

    assert login(a).get(f"/posts/{post_id}").json()["yourReaction"] == "heart"


def test_get_missing_or_removed_post_is_404(login, people, media, db_session):
    a, _, _ = people
    removed = Post(author_id=a.id, content="taken down", is_removed=True)
    db_session.add(removed)
    db_session.commit()
    api = login(a)
    assert api.get("/posts/9999").status_code == 404
    res = api.get(f"/posts/{removed.id}")
    assert res.status_code == 404 and res.json() == {"code": 404, "message": "Post not found"}


def test_email_never_in_post(login, people, media):
    a, b, _ = people
    post_id = login(a).post("/posts", data={"content": "hi"}).json()["postId"]
    assert "khi.iba.edu.pk" not in login(b).get(f"/posts/{post_id}").text


# ---------- DELETE /posts/{id} ----------


def test_author_deletes_post_and_everything_attached(login, people, media, db_session):
    a, b, _ = people
    post_id = login(a).post("/posts", data={"content": "oops"}).json()["postId"]
    hl = Highlight(owner_id=a.id, title="Finals")
    db_session.add_all([
        Reaction(post_id=post_id, student_id=b.id, kind="laugh"),
        Comment(post_id=post_id, author_id=b.id, text="lol"),
        Report(reporter_id=b.id, post_id=post_id, reason="spam"),
        hl,
    ])
    db_session.flush()
    db_session.add(HighlightPost(highlight_id=hl.id, post_id=post_id))
    db_session.commit()

    res = login(a).delete(f"/posts/{post_id}")
    assert res.status_code == 200 and res.json() == {"message": "Post deleted"}
    db_session.expire_all()
    assert db_session.get(Post, post_id) is None
    for model in (Reaction, Comment, Report, HighlightPost):
        assert db_session.scalars(select(model).where(model.post_id == post_id)).all() == []
    assert db_session.get(Highlight, hl.id) is not None  # the highlight itself stays
    assert login(a).get(f"/posts/{post_id}").status_code == 404
    assert login(a).get(f"/profile/{a.id}").json()["posts"]["items"] == []


def test_only_the_author_can_delete(login, people, media, db_session):
    a, b, _ = people
    post_id = login(a).post("/posts", data={"content": "mine"}).json()["postId"]
    res = login(b).delete(f"/posts/{post_id}")
    assert res.status_code == 403 and res.json()["code"] == 403
    assert db_session.get(Post, post_id) is not None


def test_delete_missing_post_is_404(login, people):
    a, _, _ = people
    assert login(a).delete("/posts/9999").status_code == 404


# ---------- auth ----------


def test_all_post_routes_need_login(client, people):
    assert client.post("/posts", data={"content": "hi"}).status_code == 401
    assert client.get("/posts/1").status_code == 401
    assert client.delete("/posts/1").status_code == 401
