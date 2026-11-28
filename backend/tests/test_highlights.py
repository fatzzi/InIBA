"""SCRUM-37: create, edit and delete highlights on my profile (API doc 3.5 - 3.8)."""

import pytest

from app.main import app
from app.models import Highlight, HighlightPost, Post, Student
from app.security import get_current_user

BASE = "http://testserver"


@pytest.fixture()
def people(db_session):
    sara = Student(email="sara@khi.iba.edu.pk", password_hash="x", name="Sara", is_verified=True)
    hamza = Student(email="hamza@khi.iba.edu.pk", password_hash="x", name="Hamza", is_verified=True)
    db_session.add_all([sara, hamza])
    db_session.commit()
    return sara, hamza


@pytest.fixture()
def login(client):
    def _login(student: Student):
        app.dependency_overrides[get_current_user] = lambda: student
        return client

    return _login


def post(db, author: Student, image: str | None = None, **kw) -> Post:
    p = Post(author_id=author.id, image_back=image, content=None if image else "text only", **kw)
    db.add(p)
    db.commit()
    return p


def create(c, title="Library nights", post_ids=()):
    return c.post("/highlights", json={"title": title, "postIds": list(post_ids)})


# ---------- POST /highlights ----------

def test_create_returns_201_with_cover_from_first_post(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    p2 = post(db_session, sara, "/media/posts/2.jpg")

    res = create(login(sara), post_ids=[p2.id, p1.id])

    assert res.status_code == 201
    body = res.json()
    assert body["title"] == "Library nights"
    assert body["coverThumbnail"] == f"{BASE}/media/posts/2.jpg"
    assert body["posts"] == [
        {"postId": p2.id, "thumbnail": f"{BASE}/media/posts/2.jpg"},
        {"postId": p1.id, "thumbnail": f"{BASE}/media/posts/1.jpg"},
    ]
    saved = db_session.get(Highlight, body["highlightId"])
    assert saved.owner_id == sara.id


def test_create_trims_title_and_drops_duplicate_posts(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")

    res = create(login(sara), title="  Exams  ", post_ids=[p1.id, p1.id])

    assert res.status_code == 201
    assert res.json()["title"] == "Exams"
    assert [x["postId"] for x in res.json()["posts"]] == [p1.id]


def test_text_only_post_has_no_thumbnail(db_session, people, login):
    sara, _ = people
    p = post(db_session, sara)

    body = create(login(sara), post_ids=[p.id]).json()

    assert body["coverThumbnail"] is None
    assert body["posts"] == [{"postId": p.id, "thumbnail": None}]


@pytest.mark.parametrize(
    "payload",
    [
        {"title": "", "postIds": [1]},
        {"title": "   ", "postIds": [1]},
        {"title": "x" * 31, "postIds": [1]},
        {"title": "ok", "postIds": []},
        {"title": "ok", "postIds": list(range(1, 32))},
        {"title": "ok"},
        {"postIds": [1]},
    ],
)
def test_create_bad_input_is_400(db_session, people, login, payload):
    sara, _ = people
    post(db_session, sara, "/media/posts/1.jpg")

    res = login(sara).post("/highlights", json=payload)

    assert res.status_code == 400
    assert res.json()["code"] == 400


def test_create_with_someone_elses_post_is_403(db_session, people, login):
    sara, hamza = people
    mine = post(db_session, sara, "/media/posts/1.jpg")
    theirs = post(db_session, hamza, "/media/posts/2.jpg")

    res = create(login(sara), post_ids=[mine.id, theirs.id])

    assert res.status_code == 403
    assert db_session.query(Highlight).count() == 0


def test_create_with_missing_or_removed_post_is_404(db_session, people, login):
    sara, _ = people
    removed = post(db_session, sara, "/media/posts/1.jpg", is_removed=True)

    assert create(login(sara), post_ids=[9999]).status_code == 404
    assert create(login(sara), post_ids=[removed.id]).status_code == 404


def test_create_without_token_is_401(client):
    assert client.post("/highlights", json={"title": "x", "postIds": [1]}).status_code == 401


# ---------- GET /profile/{id}/highlights ----------

def test_anyone_logged_in_can_list_a_students_highlights(db_session, people, login):
    sara, hamza = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    p2 = post(db_session, sara, "/media/posts/2.jpg")
    c = login(sara)
    first = create(c, "First", [p1.id]).json()
    second = create(c, "Second", [p2.id, p1.id]).json()

    res = login(hamza).get(f"/profile/{sara.id}/highlights")

    assert res.status_code == 200
    items = res.json()["items"]
    assert [h["highlightId"] for h in items] == [first["highlightId"], second["highlightId"]]
    assert items[1]["posts"][0]["postId"] == p2.id


def test_list_is_empty_for_a_student_with_no_highlights(people, login):
    sara, hamza = people
    res = login(hamza).get(f"/profile/{sara.id}/highlights")
    assert res.status_code == 200
    assert res.json() == {"items": []}


def test_list_for_unknown_student_is_404(people, login):
    sara, _ = people
    assert login(sara).get("/profile/9999/highlights").status_code == 404


def test_removed_post_disappears_and_cover_moves_to_next(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    p2 = post(db_session, sara, "/media/posts/2.jpg")
    c = login(sara)
    create(c, post_ids=[p1.id, p2.id])

    p1.is_removed = True  # e.g. taken down by moderation
    db_session.commit()

    h = c.get(f"/profile/{sara.id}/highlights").json()["items"][0]
    assert [x["postId"] for x in h["posts"]] == [p2.id]
    assert h["coverThumbnail"] == f"{BASE}/media/posts/2.jpg"


# ---------- PATCH /highlights/{id} ----------

def test_patch_title_only_keeps_posts(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    c = login(sara)
    hid = create(c, post_ids=[p1.id]).json()["highlightId"]

    res = c.patch(f"/highlights/{hid}", json={"title": "Late nights"})

    assert res.status_code == 200
    assert res.json()["title"] == "Late nights"
    assert [x["postId"] for x in res.json()["posts"]] == [p1.id]


def test_patch_post_ids_replaces_the_list_and_cover(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    p2 = post(db_session, sara, "/media/posts/2.jpg")
    p3 = post(db_session, sara, "/media/posts/3.jpg")
    c = login(sara)
    hid = create(c, post_ids=[p1.id]).json()["highlightId"]

    # Adding timeline posts = send the new full list.
    res = c.patch(f"/highlights/{hid}", json={"postIds": [p3.id, p1.id, p2.id]})

    assert res.status_code == 200
    assert [x["postId"] for x in res.json()["posts"]] == [p3.id, p1.id, p2.id]
    assert res.json()["coverThumbnail"] == f"{BASE}/media/posts/3.jpg"
    assert db_session.get(Highlight, hid).cover_url == "/media/posts/3.jpg"


def test_patch_by_another_student_is_403(db_session, people, login):
    sara, hamza = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    hid = create(login(sara), post_ids=[p1.id]).json()["highlightId"]

    res = login(hamza).patch(f"/highlights/{hid}", json={"title": "mine now"})

    assert res.status_code == 403
    assert db_session.get(Highlight, hid).title == "Library nights"


def test_patch_adding_someone_elses_post_is_403_and_changes_nothing(db_session, people, login):
    sara, hamza = people
    mine = post(db_session, sara, "/media/posts/1.jpg")
    theirs = post(db_session, hamza, "/media/posts/2.jpg")
    c = login(sara)
    hid = create(c, post_ids=[mine.id]).json()["highlightId"]

    res = c.patch(f"/highlights/{hid}", json={"title": "New", "postIds": [mine.id, theirs.id]})

    assert res.status_code == 403
    db_session.expire_all()
    assert db_session.get(Highlight, hid).title == "Library nights"
    assert [hp.post_id for hp in db_session.query(HighlightPost).filter_by(highlight_id=hid)] == [mine.id]


@pytest.mark.parametrize(
    "payload",
    [{"title": ""}, {"title": "x" * 31}, {"postIds": []}, {"streak": 5}],
)
def test_patch_bad_input_is_400(db_session, people, login, payload):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    c = login(sara)
    hid = create(c, post_ids=[p1.id]).json()["highlightId"]

    assert c.patch(f"/highlights/{hid}", json=payload).status_code == 400


def test_patch_unknown_highlight_or_post_is_404(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    c = login(sara)
    hid = create(c, post_ids=[p1.id]).json()["highlightId"]

    assert c.patch("/highlights/9999", json={"title": "x"}).status_code == 404
    assert c.patch(f"/highlights/{hid}", json={"postIds": [9999]}).status_code == 404


# ---------- DELETE /highlights/{id} ----------

def test_delete_removes_highlight_but_keeps_posts(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    c = login(sara)
    hid = create(c, post_ids=[p1.id]).json()["highlightId"]

    res = c.delete(f"/highlights/{hid}")

    assert res.status_code == 200
    assert res.json() == {"message": "Highlight deleted"}
    assert db_session.get(Highlight, hid) is None
    assert db_session.query(HighlightPost).count() == 0
    assert db_session.get(Post, p1.id) is not None
    assert c.get(f"/profile/{sara.id}/highlights").json() == {"items": []}


def test_delete_by_another_student_is_403(db_session, people, login):
    sara, hamza = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    hid = create(login(sara), post_ids=[p1.id]).json()["highlightId"]

    assert login(hamza).delete(f"/highlights/{hid}").status_code == 403
    assert db_session.get(Highlight, hid) is not None


def test_delete_unknown_highlight_is_404(people, login):
    sara, _ = people
    assert login(sara).delete("/highlights/9999").status_code == 404


def test_deleting_a_post_takes_it_out_of_highlights(db_session, people, login):
    sara, _ = people
    p1 = post(db_session, sara, "/media/posts/1.jpg")
    p2 = post(db_session, sara, "/media/posts/2.jpg")
    c = login(sara)
    create(c, post_ids=[p1.id, p2.id])

    assert c.delete(f"/posts/{p1.id}").status_code == 200

    h = c.get(f"/profile/{sara.id}/highlights").json()["items"][0]
    assert [x["postId"] for x in h["posts"]] == [p2.id]
