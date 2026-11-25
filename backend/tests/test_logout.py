"""Tests for SCRUM-70: POST /auth/logout revokes the student's JWT."""

from app.models import Student
from app.security import create_access_token, hash_password


def _student(db, email="ali@khi.iba.edu.pk") -> Student:
    s = Student(email=email, password_hash=hash_password("password123"), name="Ali", is_verified=True)
    db.add(s)
    db.commit()
    db.refresh(s)
    return s


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_logout_returns_200_and_bumps_token_version(client, db_session):
    s = _student(db_session)
    token = create_access_token(s.id, token_version=s.token_version)

    res = client.post("/auth/logout", headers=_auth(token))

    assert res.status_code == 200
    assert res.json() == {"message": "Logged out"}
    db_session.refresh(s)
    assert s.token_version == 1


def test_old_token_is_rejected_after_logout(client, db_session):
    s = _student(db_session)
    token = create_access_token(s.id, token_version=s.token_version)
    client.post("/auth/logout", headers=_auth(token))

    res = client.get(f"/profile/{s.id}", headers=_auth(token))

    assert res.status_code == 401
    assert res.json()["message"] == "Session has ended. Please log in again"


def test_logout_twice_with_same_token_is_401(client, db_session):
    s = _student(db_session)
    token = create_access_token(s.id, token_version=s.token_version)

    assert client.post("/auth/logout", headers=_auth(token)).status_code == 200
    assert client.post("/auth/logout", headers=_auth(token)).status_code == 401


def test_new_token_after_logout_works(client, db_session):
    s = _student(db_session)
    old = create_access_token(s.id, token_version=s.token_version)
    client.post("/auth/logout", headers=_auth(old))
    db_session.refresh(s)

    new = create_access_token(s.id, token_version=s.token_version)

    assert client.get(f"/profile/{s.id}", headers=_auth(new)).status_code == 200


def test_logout_without_token_is_401(client):
    assert client.post("/auth/logout").status_code == 401


def test_logout_only_affects_that_student(client, db_session):
    a = _student(db_session, "a@khi.iba.edu.pk")
    b = _student(db_session, "b@khi.iba.edu.pk")
    token_a = create_access_token(a.id, token_version=a.token_version)
    token_b = create_access_token(b.id, token_version=b.token_version)

    client.post("/auth/logout", headers=_auth(token_a))

    assert client.get(f"/profile/{b.id}", headers=_auth(token_b)).status_code == 200
