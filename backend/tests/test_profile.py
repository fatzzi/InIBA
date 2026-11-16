"""SCRUM-32: GET/PATCH /profile/{id}."""

import json
from datetime import date, datetime, time, timedelta, timezone
from io import BytesIO

import jwt
import pytest
from PIL import Image

from app.config import get_settings
from app.deps import get_current_student
from app.main import app
from app.models import Post, Society, Student
from app.services.profile import CAMPUS_TZ, streak_from_days
from app.storage import LocalImageStore, get_image_store

EMAIL_A = "sara.a@khi.iba.edu.pk"
EMAIL_B = "hamza.k@khi.iba.edu.pk"


@pytest.fixture()
def people(db_session):
    societies = [Society(name="IEEE"), Society(name="Drama Society"), Society(name="Music Society")]
    a = Student(email=EMAIL_A, password_hash="x", name="Sara A.", batch="2027", department="Business",
                is_verified=True, bio="need coffee", mood_sticker="sleepy", tags=["need coffee"])
    b = Student(email=EMAIL_B, password_hash="x", name="Hamza K.", batch="2026",
                department="Computer Science", is_verified=True)
    db_session.add_all([*societies, a, b])
    db_session.flush()
    a.societies = [societies[0]]
    db_session.commit()
    return a, b


@pytest.fixture()
def as_student(client):
    """Log in as a student by overriding the JWT dependency."""

    def login(student: Student):
        app.dependency_overrides[get_current_student] = lambda: student
        return client

    return login


@pytest.fixture()
def media(tmp_path):
    store = LocalImageStore(root=tmp_path, base_url="/media")
    app.dependency_overrides[get_image_store] = lambda: store
    return tmp_path


def _campus_noon(days_ago: int) -> datetime:
    day = datetime.now(CAMPUS_TZ).date() - timedelta(days=days_ago)
    return datetime.combine(day, time(12), tzinfo=CAMPUS_TZ).astimezone(timezone.utc)


def _post(db, author, days_ago=0, **kw) -> Post:
    p = Post(author_id=author.id, created_at=_campus_noon(days_ago), **kw)
    db.add(p)
    db.commit()
    return p


def _png(w: int, h: int, fmt: str = "PNG") -> bytes:
    buf = BytesIO()
    Image.new("RGB", (w, h), (200, 30, 30)).save(buf, fmt)
    return buf.getvalue()


# ---------- GET ----------


def test_get_own_profile_shape(as_student, people, db_session):
    a, _ = people
    _post(db_session, a, content="Library grind", image_back="/media/p/1b.jpg")
    res = as_student(a).get(f"/profile/{a.id}")
    assert res.status_code == 200
    body = res.json()
    assert body["studentId"] == a.id
    assert body["name"] == "Sara A." and body["batch"] == "2027" and body["department"] == "Business"
    assert body["bio"] == "need coffee" and body["moodSticker"] == "sleepy"
    assert body["societies"] == ["IEEE"] and body["tags"] == ["need coffee"]
    assert body["streak"] == 1 and body["profilePhoto"] is None
    assert body["posts"]["isMore"] is False
    [item] = body["posts"]["items"]
    assert item["excerpt"] == "Library grind"
    assert item["thumbnail"] == "http://testserver/media/p/1b.jpg"


def test_get_other_profile_never_exposes_email(as_student, people):
    a, b = people
    for viewer, target in [(b, a), (a, a)]:
        res = as_student(viewer).get(f"/profile/{target.id}")
        assert res.status_code == 200
        text = res.text
        assert "email" not in json.loads(text)
        assert EMAIL_A not in text and EMAIL_B not in text


def test_get_unknown_is_404(as_student, people):
    a, _ = people
    res = as_student(a).get("/profile/9999")
    assert res.status_code == 404
    assert res.json() == {"code": 404, "message": "Student not found"}


def test_unverified_student_is_404(as_student, people, db_session):
    a, _ = people
    ghost = Student(email="ghost@khi.iba.edu.pk", password_hash="x", name="Ghost")
    db_session.add(ghost)
    db_session.commit()
    assert as_student(a).get(f"/profile/{ghost.id}").status_code == 404


def test_no_token_is_401(client, people):
    a, _ = people
    res = client.get(f"/profile/{a.id}")
    assert res.status_code == 401
    assert res.json()["code"] == 401
    assert client.patch(f"/profile/{a.id}", json={"bio": "x"}).status_code == 401


def test_real_jwt_dependency(client, people):
    """The stand-in JWT dependency accepts a signed token and rejects bad ones."""
    a, _ = people
    secret = get_settings().jwt_secret
    good = jwt.encode({"sub": str(a.id)}, secret, algorithm="HS256")
    expired = jwt.encode({"sub": str(a.id), "exp": datetime.now(timezone.utc) - timedelta(minutes=1)},
                         secret, algorithm="HS256")
    forged = jwt.encode({"sub": str(a.id)}, "wrong-secret", algorithm="HS256")
    assert client.get(f"/profile/{a.id}", headers={"Authorization": f"Bearer {good}"}).status_code == 200
    for token in (expired, forged, "garbage"):
        assert client.get(f"/profile/{a.id}", headers={"Authorization": f"Bearer {token}"}).status_code == 401


def test_suspended_student_is_403(client, people, db_session):
    a, _ = people
    a.is_suspended = True
    db_session.commit()
    token = jwt.encode({"sub": str(a.id)}, get_settings().jwt_secret, algorithm="HS256")
    assert client.get(f"/profile/{a.id}", headers={"Authorization": f"Bearer {token}"}).status_code == 403


def test_post_grid_paging_and_filters(as_student, people, db_session):
    a, b = people
    for i in range(55):
        _post(db_session, a, content=f"post {i}", image_front=f"/media/p/{i}f.jpg")
    _post(db_session, a, content="removed", is_removed=True)
    _post(db_session, b, content="not mine")
    client = as_student(b)

    first = client.get(f"/profile/{a.id}", params={"limit": 20}).json()["posts"]
    assert len(first["items"]) == 20 and first["isMore"] is True

    capped = client.get(f"/profile/{a.id}", params={"limit": 500}).json()["posts"]
    assert len(capped["items"]) == 50 and capped["isMore"] is True

    last = client.get(f"/profile/{a.id}", params={"offset": 50, "limit": 50}).json()["posts"]
    assert len(last["items"]) == 5 and last["isMore"] is False

    excerpts = {i["excerpt"] for i in capped["items"] + last["items"]}
    assert "removed" not in excerpts and "not mine" not in excerpts

    stamps = [i["postId"] for i in first["items"]]
    assert stamps == sorted(stamps, reverse=True)  # same day posts: newest id first

    assert client.get(f"/profile/{a.id}", params={"offset": -1}).status_code == 400


def test_post_grid_newest_first_across_days(as_student, people, db_session):
    a, _ = people
    old = _post(db_session, a, days_ago=2, content="old")
    new = _post(db_session, a, days_ago=0, content="new")
    items = as_student(a).get(f"/profile/{a.id}").json()["posts"]["items"]
    assert [i["postId"] for i in items] == [new.id, old.id]


def test_text_post_excerpt_and_no_thumbnail(as_student, people, db_session):
    a, _ = people
    _post(db_session, a, content="x" * 100)
    [item] = as_student(a).get(f"/profile/{a.id}").json()["posts"]["items"]
    assert item["thumbnail"] is None
    assert item["excerpt"] == "x" * 60


# ---------- streak ----------


def test_streak_rules():
    today = date(2026, 11, 16)
    d = lambda n: today - timedelta(days=n)  # noqa: E731
    assert streak_from_days([], today) == 0
    assert streak_from_days([d(0)], today) == 1
    assert streak_from_days([d(0), d(1), d(2)], today) == 3
    assert streak_from_days([d(0), d(1), d(3), d(4)], today) == 2  # gap resets
    assert streak_from_days([d(1), d(2)], today) == 2  # yesterday-only still counts
    assert streak_from_days([d(2), d(3)], today) == 0  # a fully missed day breaks it


def test_streak_through_api_ignores_removed_and_uses_campus_days(as_student, people, db_session):
    a, _ = people
    for n in (0, 1, 2):
        _post(db_session, a, days_ago=n, content="x")
    _post(db_session, a, days_ago=3, content="x", is_removed=True)
    _post(db_session, a, days_ago=4, content="x")
    assert as_student(a).get(f"/profile/{a.id}").json()["streak"] == 3


def test_stored_streak_count_is_ignored(as_student, people, db_session):
    a, _ = people
    a.streak_count = 99
    db_session.commit()
    assert as_student(a).get(f"/profile/{a.id}").json()["streak"] == 0


# ---------- PATCH ----------


def test_patch_json_happy_path(as_student, people, db_session):
    a, _ = people
    res = as_student(a).patch(f"/profile/{a.id}", json={
        "bio": "exam week", "moodSticker": "stressed", "department": "Accounting", "batch": "2028",
        "societies": ["Drama Society", "Music Society"], "tags": ["night owl", "chai"],
    })
    assert res.status_code == 200
    body = res.json()
    assert "posts" not in body and "email" not in body
    assert body["bio"] == "exam week" and body["moodSticker"] == "stressed"
    assert body["department"] == "Accounting" and body["batch"] == "2028"
    assert body["societies"] == ["Drama Society", "Music Society"]  # replaced, IEEE gone
    assert body["tags"] == ["night owl", "chai"]
    db_session.refresh(a)
    assert a.bio == "exam week" and [s.name for s in a.societies] != ["IEEE"]


def test_patch_partial_leaves_other_fields(as_student, people):
    a, _ = people
    body = as_student(a).patch(f"/profile/{a.id}", json={"bio": "new bio"}).json()
    assert body["bio"] == "new bio"
    assert body["moodSticker"] == "sleepy" and body["tags"] == ["need coffee"] and body["societies"] == ["IEEE"]


def test_patch_empty_lists_clear(as_student, people):
    a, _ = people
    body = as_student(a).patch(f"/profile/{a.id}", json={"tags": [], "societies": []}).json()
    assert body["tags"] == [] and body["societies"] == []


def test_patch_other_student_is_403(as_student, people, db_session):
    a, b = people
    res = as_student(b).patch(f"/profile/{a.id}", json={"bio": "hacked"})
    assert res.status_code == 403
    assert res.json()["code"] == 403
    db_session.refresh(a)
    assert a.bio == "need coffee"


def test_patch_unknown_is_404(as_student, people):
    a, _ = people
    assert as_student(a).patch("/profile/9999", json={"bio": "x"}).status_code == 404


@pytest.mark.parametrize("payload", [
    {"bio": "x" * 151},
    {"tags": ["a", "b", "c", "d", "e", "f"]},
    {"tags": ["x" * 21]},
    {"tags": [""]},
    {"streak": 10},
    {"email": "new@khi.iba.edu.pk"},
    {"societies": ["Not A Society"]},
])
def test_patch_validation_is_400(as_student, people, payload):
    a, _ = people
    res = as_student(a).patch(f"/profile/{a.id}", json=payload)
    assert res.status_code == 400, payload
    assert res.json()["code"] == 400


def test_patch_bio_of_150_is_ok(as_student, people):
    a, _ = people
    assert as_student(a).patch(f"/profile/{a.id}", json={"bio": "x" * 150}).status_code == 200


def test_patch_bad_body_is_400(as_student, people):
    a, _ = people
    client = as_student(a)
    for body in ("not json", "[1, 2]"):
        res = client.patch(f"/profile/{a.id}", content=body, headers={"content-type": "application/json"})
        assert res.status_code == 400


def test_mood_set_at_changes_only_when_mood_changes(as_student, people, db_session):
    a, _ = people
    client = as_student(a)
    assert a.mood_set_at is None

    client.patch(f"/profile/{a.id}", json={"bio": "only bio"})
    db_session.refresh(a)
    assert a.mood_set_at is None

    client.patch(f"/profile/{a.id}", json={"moodSticker": "happy"})
    db_session.refresh(a)
    first = a.mood_set_at
    assert first is not None

    client.patch(f"/profile/{a.id}", json={"moodSticker": "happy"})
    db_session.refresh(a)
    assert a.mood_set_at == first


# ---------- photo (multipart) ----------


def test_patch_multipart_valid_photo(as_student, people, media):
    a, _ = people
    res = as_student(a).patch(
        f"/profile/{a.id}",
        data={"bio": "with photo", "tags": ["chai", "library"]},
        files={"profilePhoto": ("me.png", _png(400, 400), "image/png")},
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["bio"] == "with photo" and body["tags"] == ["chai", "library"]
    assert body["profilePhoto"].startswith("http://testserver/media/profile/")
    assert body["profilePhoto"].endswith(".png")
    stored = list((media / "profile").iterdir())
    assert len(stored) == 1


def test_patch_multipart_jpeg_and_json_list(as_student, people, media):
    a, _ = people
    res = as_student(a).patch(
        f"/profile/{a.id}",
        data={"societies": '["IEEE", "Drama Society"]'},
        files={"profilePhoto": ("me.jpg", _png(808, 800, "JPEG"), "image/jpeg")},  # within 2% of square
    )
    assert res.status_code == 200, res.text
    assert res.json()["profilePhoto"].endswith(".jpg")
    assert res.json()["societies"] == ["Drama Society", "IEEE"]


@pytest.mark.parametrize("image", [
    _png(399, 399),                # too small
    _png(800, 600),                # not square
    _png(400, 400, "GIF"),         # wrong format
    b"definitely not an image",
])
def test_patch_bad_photo_is_400_and_stores_nothing(as_student, people, media, db_session, image):
    a, _ = people
    res = as_student(a).patch(f"/profile/{a.id}", files={"profilePhoto": ("x.png", image, "image/png")})
    assert res.status_code == 400
    assert res.json()["code"] == 400
    assert not (media / "profile").exists()
    db_session.refresh(a)
    assert a.profile_photo is None


def test_unknown_society_with_photo_stores_nothing(as_student, people, media):
    a, _ = people
    res = as_student(a).patch(
        f"/profile/{a.id}",
        data={"societies": "Nope"},
        files={"profilePhoto": ("me.png", _png(400, 400), "image/png")},
    )
    assert res.status_code == 400
    assert not (media / "profile").exists()
