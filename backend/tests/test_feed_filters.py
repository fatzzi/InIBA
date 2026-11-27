"""SCRUM-29: GET /feed filters (test strategy FILT-01 to FILT-04) and GET /locations (CONT-15)."""

from datetime import datetime, timedelta, timezone

import pytest

from app.main import app
from app.models import LocationTag, Post, Society, Student
from app.security import get_current_user

NOW = datetime(2026, 11, 26, 9, 0, tzinfo=timezone.utc)


@pytest.fixture()
def campus(db_session):
    """Seeded posts across zones, departments, societies and batches (FILT-01 prerequisites)."""
    library, ced, hostel = (LocationTag(zone_name=z) for z in ("Library", "CED", "Hostel"))
    debating, ieee = Society(name="Debating Society"), Society(name="IEEE")
    sara = Student(email="sara.a@khi.iba.edu.pk", password_hash="x", name="Sara A.", is_verified=True,
                   batch="2027", department="Business", societies=[debating, ieee])
    hamza = Student(email="hamza.k@khi.iba.edu.pk", password_hash="x", name="Hamza K.", is_verified=True,
                    batch="2026", department="Computer Science", societies=[ieee])
    ayesha = Student(email="ayesha.r@khi.iba.edu.pk", password_hash="x", name="Ayesha R.", is_verified=True,
                     batch="2027", department="Economics")
    db_session.add_all([library, ced, hostel, debating, ieee, sara, hamza, ayesha])
    db_session.commit()

    posts = {}
    for i, (key, author, zone) in enumerate([
        ("sara_library", sara, library),
        ("sara_ced", sara, ced),
        ("sara_none", sara, None),
        ("hamza_library", hamza, library),
        ("hamza_ced", hamza, ced),
        ("ayesha_library", ayesha, library),
    ]):
        p = Post(author_id=author.id, content=key, location_tag_id=zone and zone.id,
                 created_at=NOW - timedelta(minutes=10 * i))
        db_session.add(p)
        posts[key] = p
    db_session.commit()
    return {"zones": (library, ced, hostel), "people": (sara, hamza, ayesha), "posts": posts}


@pytest.fixture()
def api(client, campus):
    app.dependency_overrides[get_current_user] = lambda: campus["people"][2]  # Ayesha, batch 2027
    return client


def contents(res) -> list[str]:
    assert res.status_code == 200, res.text
    return [p["content"] for p in res.json()["items"]]


ALL = ["sara_library", "sara_ced", "sara_none", "hamza_library", "hamza_ced", "ayesha_library"]


def test_no_filters_is_the_whole_feed(api):
    assert contents(api.get("/feed")) == ALL


# ---------- FILT-01: one filter at a time ----------


def test_zone_matches_the_posts_location_tag(api, campus):
    library, ced, _ = campus["zones"]
    assert contents(api.get("/feed", params={"zone": library.id})) == ["sara_library", "hamza_library", "ayesha_library"]
    assert contents(api.get("/feed", params={"zone": ced.id})) == ["sara_ced", "hamza_ced"]


@pytest.mark.parametrize("value", ["Computer Science", "computer science", "  COMPUTER SCIENCE "])
def test_department_matches_the_author_ignoring_case_and_spaces(api, value):
    assert contents(api.get("/feed", params={"department": value})) == ["hamza_library", "hamza_ced"]


def test_society_matches_any_society_the_author_belongs_to(api):
    assert contents(api.get("/feed", params={"society": "debating society"})) == ["sara_library", "sara_ced", "sara_none"]
    assert contents(api.get("/feed", params={"society": "IEEE"})) == [
        "sara_library", "sara_ced", "sara_none", "hamza_library", "hamza_ced",
    ]


def test_batch_matches_the_authors_graduating_year(api):
    assert contents(api.get("/feed", params={"batch": 2026})) == ["hamza_library", "hamza_ced"]
    assert contents(api.get("/feed", params={"batch": "2027"})) == [
        "sara_library", "sara_ced", "sara_none", "ayesha_library",
    ]


# ---------- FILT-02: filters stack with AND ----------


def test_library_and_own_batch(api, campus):
    """The Jira acceptance example: zone=Library + own batch returns only matching posts."""
    library = campus["zones"][0]
    assert contents(api.get("/feed", params={"zone": library.id, "batch": 2027})) == ["sara_library", "ayesha_library"]


def test_all_four_filters_together(api, campus):
    library, ced, _ = campus["zones"]
    params = {"zone": library.id, "department": "business", "society": "IEEE", "batch": 2027}
    assert contents(api.get("/feed", params=params)) == ["sara_library"]
    assert contents(api.get("/feed", params={**params, "zone": ced.id})) == ["sara_ced"]


def test_filters_keep_paging(api):
    first = api.get("/feed", params={"batch": 2027, "limit": 3}).json()
    assert first["isMore"] is True and [p["content"] for p in first["items"]] == ["sara_library", "sara_ced", "sara_none"]
    second = api.get("/feed", params={"batch": 2027, "limit": 3, "offset": 3}).json()
    assert second["isMore"] is False and [p["content"] for p in second["items"]] == ["ayesha_library"]


def test_filters_still_leave_out_removed_posts_and_unverified_authors(api, campus, db_session):
    library = campus["zones"][0]
    campus["posts"]["sara_library"].is_removed = True
    pending = Student(email="new.kid@khi.iba.edu.pk", password_hash="x", name="New Kid", is_verified=False, batch="2027")
    db_session.add(pending)
    db_session.flush()
    db_session.add(Post(author_id=pending.id, content="pending", location_tag_id=library.id, created_at=NOW))
    db_session.commit()
    assert contents(api.get("/feed", params={"zone": library.id, "batch": 2027})) == ["ayesha_library"]


# ---------- FILT-03: empty result ----------


@pytest.mark.parametrize(
    "params",
    [
        {"batch": 2030},
        {"department": "Law"},
        {"society": "Chess Club"},
        {"department": "Economics", "society": "IEEE"},  # each matches someone, together no one
    ],
)
def test_no_match_is_200_with_empty_items(api, params):
    assert api.get("/feed", params=params).json() == {"isMore": False, "items": []}


def test_known_zone_with_no_posts_is_empty(api, campus):
    hostel = campus["zones"][2]
    assert api.get("/feed", params={"zone": hostel.id}).json() == {"isMore": False, "items": []}


def test_blank_text_filters_are_ignored(api):
    assert contents(api.get("/feed", params={"department": "", "society": "   "})) == ALL


# ---------- FILT-04: invalid values ----------


@pytest.mark.parametrize(
    "params",
    [
        {"zone": 999},
        {"zone": "library"},
        {"batch": "twenty"},
        {"batch": 27},
        {"department": "x" * 81},
    ],
)
def test_invalid_filter_value_is_400(api, params):
    res = api.get("/feed", params=params)
    assert res.status_code == 400 and res.json()["code"] == 400


def test_unknown_zone_message(api):
    assert api.get("/feed", params={"zone": 999}).json()["message"] == "Unknown zone"


# ---------- GET /locations (CONT-15) ----------


def test_locations_lists_the_preset_zones_in_id_order(api, campus):
    library, ced, hostel = campus["zones"]
    assert api.get("/locations").json() == {
        "items": [
            {"tagId": library.id, "zoneName": "Library"},
            {"tagId": ced.id, "zoneName": "CED"},
            {"tagId": hostel.id, "zoneName": "Hostel"},
        ]
    }


def test_every_listed_zone_is_a_valid_feed_filter(api):
    for zone in api.get("/locations").json()["items"]:
        assert api.get("/feed", params={"zone": zone["tagId"]}).status_code == 200


def test_locations_and_filtered_feed_need_login(client, campus):
    assert client.get("/locations").status_code == 401
    assert client.get("/feed", params={"batch": 2027}).status_code == 401
