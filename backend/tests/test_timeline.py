"""SCRUM-36: GET /profile/{id}/timeline (API doc 3.4; test strategy PROF-15)."""

from datetime import datetime, time, timedelta, timezone

import pytest

from app.security import get_current_user
from app.main import app
from app.models import Post, Student
from app.services.profile import CAMPUS_TZ


@pytest.fixture()
def people(db_session):
    a = Student(email="sara.a@khi.iba.edu.pk", password_hash="x", name="Sara A.", is_verified=True)
    b = Student(email="hamza.k@khi.iba.edu.pk", password_hash="x", name="Hamza K.", is_verified=True)
    db_session.add_all([a, b])
    db_session.commit()
    return a, b


@pytest.fixture()
def api(client, people):
    app.dependency_overrides[get_current_user] = lambda: people[0]
    return client


def _today():
    return datetime.now(CAMPUS_TZ).date()


def _at(days_ago: int, hour: int = 12, minute: int = 0) -> datetime:
    day = _today() - timedelta(days=days_ago)
    return datetime.combine(day, time(hour, minute), tzinfo=CAMPUS_TZ).astimezone(timezone.utc)


def _post(db, author, when: datetime, **kw) -> Post:
    p = Post(author_id=author.id, created_at=when, **kw)
    db.add(p)
    db.commit()
    return p


def test_groups_posts_by_day_newest_first(api, people, db_session):
    a, _ = people
    old = _post(db_session, a, _at(3), content="Debate practice")
    y = _post(db_session, a, _at(1), image_front="/media/p/f.jpg", image_back="/media/p/b.jpg")
    t1 = _post(db_session, a, _at(0, 9), content="Morning chai")
    t2 = _post(db_session, a, _at(0, 15), content="Library grind before midterms")

    res = api.get(f"/profile/{a.id}/timeline")
    assert res.status_code == 200
    body = res.json()
    assert body["isMore"] is False
    days = body["items"]
    assert [d["date"] for d in days] == [
        _today().isoformat(),
        (_today() - timedelta(days=1)).isoformat(),
        (_today() - timedelta(days=3)).isoformat(),
    ]
    assert [p["postId"] for p in days[0]["posts"]] == [t2.id, t1.id]  # newest first inside a day
    assert days[1]["posts"][0]["postId"] == y.id
    assert days[2]["posts"][0]["postId"] == old.id


def test_post_shape_matches_api_doc(api, people, db_session):
    a, _ = people
    _post(db_session, a, _at(0), content="x" * 80, image_front="/media/p/f.jpg", image_back="/media/p/b.jpg")
    post = api.get(f"/profile/{a.id}/timeline").json()["items"][0]["posts"][0]
    assert set(post) == {"postId", "thumbnail", "excerpt", "timestamp"}
    assert post["thumbnail"] == "http://testserver/media/p/b.jpg"  # back camera wins, made absolute
    assert post["excerpt"] == "x" * 60
    assert post["timestamp"].endswith("Z")
    assert datetime.fromisoformat(post["timestamp"]) == _at(0)


def test_text_post_has_no_thumbnail_and_photo_post_no_excerpt(api, people, db_session):
    a, _ = people
    _post(db_session, a, _at(0, 10), content="Text only")
    _post(db_session, a, _at(0, 11), image_front="https://cdn.example/f.jpg")
    photo, text = api.get(f"/profile/{a.id}/timeline").json()["items"][0]["posts"]
    assert photo["thumbnail"] == "https://cdn.example/f.jpg" and photo["excerpt"] is None
    assert text["thumbnail"] is None and text["excerpt"] == "Text only"


def test_days_follow_campus_time_not_utc(api, people, db_session):
    a, _ = people
    # 00:30 in Karachi is 19:30 UTC the day before: it still belongs to the Karachi day.
    _post(db_session, a, _at(0, 0, 30), content="Just after midnight")
    _post(db_session, a, _at(1, 23, 30), content="Just before midnight")
    days = api.get(f"/profile/{a.id}/timeline").json()["items"]
    assert [d["date"] for d in days] == [_today().isoformat(), (_today() - timedelta(days=1)).isoformat()]


def test_removed_posts_and_other_students_are_left_out(api, people, db_session):
    a, b = people
    _post(db_session, a, _at(0), content="kept")
    _post(db_session, a, _at(1), content="removed", is_removed=True)
    _post(db_session, b, _at(0), content="not mine")
    days = api.get(f"/profile/{a.id}/timeline").json()["items"]
    assert len(days) == 1
    assert [p["excerpt"] for p in days[0]["posts"]] == ["kept"]


def test_offset_and_limit_count_days_not_posts(api, people, db_session):
    a, _ = people
    for d in range(5):
        for h in (9, 12, 15):  # three posts a day
            _post(db_session, a, _at(d, h), content=f"day {d} {h}")
    first = api.get(f"/profile/{a.id}/timeline", params={"limit": 2}).json()
    assert first["isMore"] is True
    assert len(first["items"]) == 2 and all(len(d["posts"]) == 3 for d in first["items"])

    second = api.get(f"/profile/{a.id}/timeline", params={"offset": 2, "limit": 2}).json()
    assert second["isMore"] is True
    assert second["items"][0]["date"] == (_today() - timedelta(days=2)).isoformat()

    last = api.get(f"/profile/{a.id}/timeline", params={"offset": 4, "limit": 2}).json()
    assert last["isMore"] is False and len(last["items"]) == 1

    past_end = api.get(f"/profile/{a.id}/timeline", params={"offset": 10}).json()
    assert past_end == {"isMore": False, "items": []}


def test_default_is_14_days_and_limit_caps_at_31(api, people, db_session):
    a, _ = people
    for d in range(40):
        _post(db_session, a, _at(d), content=f"day {d}")
    default = api.get(f"/profile/{a.id}/timeline").json()
    assert len(default["items"]) == 14 and default["isMore"] is True
    capped = api.get(f"/profile/{a.id}/timeline", params={"limit": 500}).json()
    assert len(capped["items"]) == 31


def test_empty_timeline(api, people):
    a, _ = people
    assert api.get(f"/profile/{a.id}/timeline").json() == {"isMore": False, "items": []}


def test_anyone_logged_in_can_view_another_timeline(api, people, db_session):
    _, b = people
    _post(db_session, b, _at(0), content="hello")
    res = api.get(f"/profile/{b.id}/timeline")
    assert res.status_code == 200 and len(res.json()["items"]) == 1


@pytest.mark.parametrize("params", [{"offset": -1}, {"limit": 0}, {"limit": "abc"}])
def test_bad_paging_is_400(api, people, params):
    a, _ = people
    res = api.get(f"/profile/{a.id}/timeline", params=params)
    assert res.status_code == 400
    assert set(res.json()) == {"code", "message"}


def test_unknown_or_unverified_student_is_404(api, people, db_session):
    ghost = Student(email="ghost@khi.iba.edu.pk", password_hash="x", is_verified=False)
    db_session.add(ghost)
    db_session.commit()
    assert api.get("/profile/9999/timeline").status_code == 404
    assert api.get(f"/profile/{ghost.id}/timeline").status_code == 404


def test_requires_login(client, people):
    a, _ = people
    assert client.get(f"/profile/{a.id}/timeline").status_code == 401


def test_a_new_post_is_added_to_todays_timeline_automatically(api, people):
    a, _ = people
    created = api.post("/posts", data={"content": "Chai at the cafeteria"})
    assert created.status_code == 201, created.text
    today = api.get(f"/profile/{a.id}/timeline").json()["items"][0]
    assert today["date"] == _today().isoformat()
    assert [p["postId"] for p in today["posts"]] == [created.json()["postId"]]
