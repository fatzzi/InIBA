"""SCRUM-42: daily IBA Moment window, GET /moments/current, 409/410 on POST /posts (test plan CONT-03, 17-19)."""

from datetime import date, datetime, time, timedelta, timezone
from io import BytesIO

import pytest
from PIL import Image
from pydantic import ValidationError
from sqlalchemy import func, select

from app.config import Settings
from app.main import app
from app.models import MomentWindow, Post, Student
from app.security import get_current_user
from app.services import moments
from app.services.profile import CAMPUS_TZ
from app.storage import LocalImageStore, get_image_store

DAY = date(2026, 11, 26)
OPENS = datetime(2026, 11, 26, 9, 0, tzinfo=timezone.utc)  # 14:00 in Karachi
CLOSES = OPENS + timedelta(seconds=120)
_BUF = BytesIO()
Image.new("RGB", (640, 480), (30, 90, 200)).save(_BUF, "JPEG")
PHOTO = {"imageBack": ("b.jpg", _BUF.getvalue(), "image/jpeg")}


@pytest.fixture()
def student(db_session):
    s = Student(email="sara.a@khi.iba.edu.pk", password_hash="x", name="Sara A.", is_verified=True)
    db_session.add(s)
    db_session.commit()
    return s


@pytest.fixture()
def window(db_session):
    w = MomentWindow(day=DAY, opens_at=OPENS, closes_at=CLOSES)
    db_session.add(w)
    db_session.commit()
    return w


@pytest.fixture()
def media(tmp_path):
    app.dependency_overrides[get_image_store] = lambda: LocalImageStore(root=tmp_path, base_url="/media")
    return tmp_path


@pytest.fixture()
def at(client, student, media):
    """at(time) -> client logged in as the student with the clock stopped at that time."""

    def set_clock(now: datetime, as_: Student = student):
        app.dependency_overrides[get_current_user] = lambda: as_
        app.dependency_overrides[moments.utc_now] = lambda: now
        return client

    return set_clock


def post_moment(api):
    return api.post("/posts", data={"isMoment": "true"}, files=PHOTO)


def status(api) -> dict:
    res = api.get("/moments/current")
    assert res.status_code == 200, res.text
    return res.json()


# ---------- GET /moments/current ----------


@pytest.mark.parametrize(
    "now, active, remaining",
    [
        (OPENS - timedelta(milliseconds=1), False, 0),
        (OPENS, True, 120),
        (OPENS + timedelta(seconds=33), True, 87),
        (CLOSES - timedelta(milliseconds=1), True, 1),
        (CLOSES, False, 0),
    ],
)
def test_status_around_the_window(at, window, now, active, remaining):
    assert status(at(now)) == {
        "active": active, "secondsRemaining": remaining, "alreadyPosted": False, "feedLocked": True,
    }


def test_text_post_unlocks_feed_but_is_not_the_moment(at, window):
    api = at(OPENS)
    assert api.post("/posts", data={"content": "hi"}).status_code == 201
    body = status(api)
    assert body["feedLocked"] is False and body["alreadyPosted"] is False


def test_moment_post_sets_already_posted_for_that_student_only(at, window, db_session):
    other = Student(email="hamza.k@khi.iba.edu.pk", password_hash="x", name="Hamza K.", is_verified=True)
    db_session.add(other)
    db_session.commit()
    assert post_moment(at(OPENS)).status_code == 201
    body = status(at(OPENS))
    assert body["alreadyPosted"] is True and body["feedLocked"] is False
    body = status(at(OPENS, other))
    assert body["alreadyPosted"] is False and body["feedLocked"] is True
    assert post_moment(at(OPENS, other)).status_code == 201


def test_status_resets_at_campus_midnight(at, window):
    assert post_moment(at(OPENS)).status_code == 201
    last_second = datetime(2026, 11, 26, 18, 59, 59, tzinfo=timezone.utc)  # 23:59:59 in Karachi
    assert status(at(last_second))["alreadyPosted"] is True
    body = status(at(last_second + timedelta(seconds=1)))
    assert body["alreadyPosted"] is False and body["feedLocked"] is True


def test_status_needs_login(client):
    assert client.get("/moments/current").status_code == 401


# ---------- POST /posts ----------


@pytest.mark.parametrize(
    "now, code",
    [
        (OPENS - timedelta(seconds=1), 410),
        (OPENS, 201),
        (CLOSES - timedelta(seconds=1), 201),
        (CLOSES, 410),
        (CLOSES + timedelta(hours=3), 410),
    ],
)
def test_moment_post_window_boundary(at, window, media, now, code):
    res = post_moment(at(now))
    assert res.status_code == code, res.text
    if code == 410:
        assert res.json()["code"] == 410
        assert not (media / "posts").exists()  # no files left by a refused post
    else:
        assert res.json()["isMoment"] is True


def test_second_moment_is_409_inside_and_after_the_window(at, window, media):
    assert post_moment(at(OPENS)).status_code == 201
    for now in (OPENS + timedelta(seconds=30), CLOSES + timedelta(minutes=5)):
        res = post_moment(at(now))
        assert res.status_code == 409 and res.json()["code"] == 409
    assert len(list((media / "posts").iterdir())) == 1


def test_removed_moment_does_not_give_a_second_one(at, window, db_session):
    post_id = post_moment(at(OPENS)).json()["postId"]
    db_session.get(Post, post_id).is_removed = True
    db_session.commit()
    assert post_moment(at(OPENS)).status_code == 409


def test_text_and_plain_photo_posts_are_allowed_after_the_window(at, window):
    api = at(CLOSES + timedelta(hours=1))
    assert api.post("/posts", data={"content": "missed it"}).status_code == 201
    res = api.post("/posts", files=PHOTO)
    assert res.status_code == 201 and res.json()["isMoment"] is False


def test_text_post_with_moment_flag_is_a_normal_text_post(at, window):
    res = at(CLOSES).post("/posts", data={"content": "hi", "isMoment": "true"})
    assert res.status_code == 201 and res.json()["isMoment"] is False


def test_bad_image_is_400_before_any_moment_check(at, window):
    bad = {"imageBack": ("b.jpg", b"junk", "image/jpeg")}
    assert at(CLOSES).post("/posts", data={"isMoment": "true"}, files=bad).status_code == 400


# ---------- picking the time ----------


def test_one_window_per_day_and_it_does_not_move(at, db_session):
    now = datetime(2026, 11, 26, 2, 0, tzinfo=timezone.utc)
    first = moments.window_for_today(db_session, now)
    opens = first.opens_at
    status(at(now + timedelta(hours=1)))
    again = moments.window_for_today(db_session, now + timedelta(hours=10))
    assert again.id == first.id and again.opens_at == opens
    assert db_session.scalar(select(func.count()).select_from(MomentWindow)) == 1
    tomorrow = moments.window_for_today(db_session, now + timedelta(days=1))
    assert tomorrow.id != first.id and tomorrow.day == DAY + timedelta(days=1)


def test_random_times_stay_in_the_allowed_hours_and_vary(db_session):
    picked = set()
    for i in range(60):
        now = datetime(2027, 1, 1, 19, 0, tzinfo=timezone.utc) + timedelta(days=i)  # campus midnight
        w = moments.window_for_today(db_session, now)
        opens, closes = (moments._as_utc(t).astimezone(CAMPUS_TZ) for t in (w.opens_at, w.closes_at))
        assert opens.date() == closes.date() == w.day
        assert time(9, 0) <= opens.time() and closes.time() <= time(21, 0)
        assert closes - opens == timedelta(seconds=120)
        picked.add(opens.time())
    assert len(picked) > 30


def test_server_started_mid_day_picks_a_time_still_ahead():
    now = datetime(2026, 11, 26, 15, 50, 0, 5, tzinfo=timezone.utc)  # 20:50 in Karachi
    for _ in range(200):
        opens = moments._pick_opening(now, Settings(_env_file=None))
        assert now < opens <= datetime(2026, 11, 26, 15, 58, tzinfo=timezone.utc)


def test_first_use_after_hours_is_a_passed_window(at):
    body = status(at(datetime(2026, 11, 26, 17, 0, tzinfo=timezone.utc)))  # 22:00 in Karachi
    assert body["active"] is False and body["secondsRemaining"] == 0


@pytest.mark.parametrize(
    "bad",
    [
        {"moment_earliest": "21:00", "moment_latest": "09:00"},
        {"moment_earliest": "09:00", "moment_latest": "09:01"},
        {"moment_duration_seconds": 0},
    ],
)
def test_impossible_hours_are_refused_at_startup(bad):
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **bad)
