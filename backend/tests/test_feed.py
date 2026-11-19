"""SCRUM-40: GET /feed."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import event

from app.deps import get_current_student
from app.main import app
from app.models import Comment, LocationTag, Post, Reaction, Student

NOW = datetime(2026, 11, 19, 9, 0, tzinfo=timezone.utc)


@pytest.fixture()
def people(db_session):
    a = Student(email="sara.a@khi.iba.edu.pk", password_hash="x", name="Sara A.", is_verified=True,
                profile_photo="/media/profile/sara.jpg")
    b = Student(email="hamza.k@khi.iba.edu.pk", password_hash="x", name="Hamza K.", is_verified=True)
    pending = Student(email="new.kid@khi.iba.edu.pk", password_hash="x", name="New Kid", is_verified=False)
    db_session.add_all([a, b, pending])
    db_session.commit()
    return a, b, pending


@pytest.fixture()
def login(client):
    def as_(student: Student):
        app.dependency_overrides[get_current_student] = lambda: student
        return client

    return as_


def _post(db, author, minutes_ago: int, **kw) -> Post:
    p = Post(author_id=author.id, created_at=NOW - timedelta(minutes=minutes_ago), **kw)
    db.add(p)
    db.commit()
    return p


def test_newest_first_from_everyone(login, people, db_session):
    a, b, _ = people
    old = _post(db_session, a, 60, content="old")
    mid = _post(db_session, b, 30, content="mid")
    new = _post(db_session, a, 5, content="new")
    res = login(b).get("/feed")
    assert res.status_code == 200
    body = res.json()
    assert body["isMore"] is False
    assert [p["postId"] for p in body["items"]] == [new.id, mid.id, old.id]


def test_items_use_the_full_post_shape(login, people, db_session):
    a, b, _ = people
    zone = LocationTag(zone_name="Library")
    db_session.add(zone)
    db_session.commit()
    _post(db_session, a, 1, content="Library grind", image_back="/media/posts/b.jpg",
          image_front="https://cdn.example/f.jpg", location_tag_id=zone.id, is_moment=True)
    item = login(b).get("/feed").json()["items"][0]
    assert set(item) == {
        "postId", "studentId", "author", "content", "imageBack", "imageFront", "timestamp", "isRemoved",
        "isMoment", "locationTag", "reactionCount", "commentCount", "yourReaction",
    }
    assert item["author"] == {
        "studentId": a.id, "name": "Sara A.", "profilePhoto": "http://testserver/media/profile/sara.jpg",
    }
    assert item["imageBack"] == "http://testserver/media/posts/b.jpg"
    assert item["imageFront"] == "https://cdn.example/f.jpg"
    assert item["locationTag"] == {"tagId": zone.id, "zoneName": "Library"}
    assert item["isMoment"] is True and item["isRemoved"] is False
    assert item["timestamp"] == "2026-11-19T08:59:00Z"
    assert "khi.iba.edu.pk" not in login(b).get("/feed").text  # emails never leak


def test_counts_and_your_reaction_per_viewer(login, people, db_session):
    a, b, _ = people
    p1 = _post(db_session, a, 10, content="one")
    p2 = _post(db_session, b, 5, content="two")
    db_session.add_all([
        Reaction(post_id=p1.id, student_id=a.id, kind="heart"),
        Reaction(post_id=p1.id, student_id=b.id, kind="fire"),
        Reaction(post_id=p2.id, student_id=a.id, kind="laugh"),
        Comment(post_id=p1.id, author_id=b.id, text="nice"),
        Comment(post_id=p1.id, author_id=a.id, text="thanks"),
    ])
    db_session.commit()

    by_id = {p["postId"]: p for p in login(b).get("/feed").json()["items"]}
    assert (by_id[p1.id]["reactionCount"], by_id[p1.id]["commentCount"], by_id[p1.id]["yourReaction"]) == (2, 2, "fire")
    assert (by_id[p2.id]["reactionCount"], by_id[p2.id]["commentCount"], by_id[p2.id]["yourReaction"]) == (1, 0, None)

    by_id = {p["postId"]: p for p in login(a).get("/feed").json()["items"]}
    assert by_id[p1.id]["yourReaction"] == "heart" and by_id[p2.id]["yourReaction"] == "laugh"


def test_removed_posts_and_unverified_authors_are_left_out(login, people, db_session):
    a, b, pending = people
    kept = _post(db_session, a, 3, content="kept")
    _post(db_session, a, 2, content="taken down", is_removed=True)
    _post(db_session, pending, 1, content="not verified yet")
    items = login(b).get("/feed").json()["items"]
    assert [p["postId"] for p in items] == [kept.id]


def test_paging(login, people, db_session):
    a, b, _ = people
    posts = [_post(db_session, a, 100 - i, content=f"#{i}") for i in range(25)]  # posts[-1] is newest
    newest_first = [p.id for p in reversed(posts)]
    api = login(b)

    first = api.get("/feed").json()  # default limit 20
    assert first["isMore"] is True and [p["postId"] for p in first["items"]] == newest_first[:20]
    second = api.get("/feed", params={"offset": 20}).json()
    assert second["isMore"] is False and [p["postId"] for p in second["items"]] == newest_first[20:]

    small = api.get("/feed", params={"offset": 5, "limit": 5}).json()
    assert small["isMore"] is True and [p["postId"] for p in small["items"]] == newest_first[5:10]

    assert api.get("/feed", params={"offset": 100}).json() == {"isMore": False, "items": []}


def test_limit_is_capped_at_50(login, people, db_session):
    a, b, _ = people
    for i in range(55):
        _post(db_session, a, i, content=f"#{i}")
    body = login(b).get("/feed", params={"limit": 500}).json()
    assert len(body["items"]) == 50 and body["isMore"] is True


def test_same_timestamp_is_ordered_by_id(login, people, db_session):
    a, b, _ = people
    first = _post(db_session, a, 0, content="first")
    second = _post(db_session, b, 0, content="second")
    assert [p["postId"] for p in login(a).get("/feed").json()["items"]] == [second.id, first.id]


def test_empty_feed(login, people):
    _, b, _ = people
    assert login(b).get("/feed").json() == {"isMore": False, "items": []}


def test_a_new_post_appears_at_the_top(login, people, db_session):
    a, b, _ = people
    db_session.add(Post(author_id=b.id, content="older", created_at=datetime.now(timezone.utc) - timedelta(hours=1)))
    db_session.commit()
    created = login(a).post("/posts", data={"content": "just posted"}).json()
    top = login(b).get("/feed").json()["items"][0]
    assert top["postId"] == created["postId"] and top["content"] == "just posted"


def test_query_count_does_not_grow_with_page_size(login, people, db_session):
    """One page costs a fixed number of queries, however many posts are on it."""
    a, b, _ = people
    for i in range(30):
        p = _post(db_session, a if i % 2 else b, i, content=f"#{i}")
        db_session.add(Reaction(post_id=p.id, student_id=a.id, kind="clap"))
    db_session.commit()

    statements: list[str] = []
    engine = db_session.get_bind()

    def count(*args):
        statements.append(args[2])

    event.listen(engine, "before_cursor_execute", count)
    try:
        login(b).get("/feed", params={"limit": 2})
        small = len(statements)
        statements.clear()
        login(b).get("/feed", params={"limit": 30})
        large = len(statements)
    finally:
        event.remove(engine, "before_cursor_execute", count)
    assert large == small


@pytest.mark.parametrize("params", [{"offset": -1}, {"limit": 0}, {"limit": "x"}])
def test_bad_paging_is_400(login, people, params):
    _, b, _ = people
    res = login(b).get("/feed", params=params)
    assert res.status_code == 400 and set(res.json()) == {"code", "message"}


def test_feed_needs_login(client, people):
    res = client.get("/feed")
    assert res.status_code == 401 and res.json()["code"] == 401
