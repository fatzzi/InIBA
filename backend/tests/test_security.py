"""Tests for SCRUM-23: JWT auth dependency and owner/admin role checks."""

import pytest
from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base, get_db
from app.errors import install_error_handlers
from app.models import Student
from app.security import (
    create_access_token,
    ensure_owner_or_admin,
    get_current_user,
    hash_password,
    require_admin,
    require_owner_or_admin,
)

engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app = FastAPI()
install_error_handlers(app)
app.dependency_overrides[get_db] = override_get_db


@app.get("/me")
def read_me(current_user: Student = Depends(get_current_user)):
    return {"id": current_user.id, "email": current_user.email, "role": current_user.role}


@app.get("/admin-only")
def admin_only(admin: Student = Depends(require_admin)):
    return {"admin_id": admin.id}


@app.get("/items/{owner_id}")
def read_owned_item(owner_id: int, current_user: Student = Depends(get_current_user)):
    ensure_owner_or_admin(owner_id, current_user)
    return {"owner_id": owner_id, "accessed_by": current_user.id}


@app.get("/direct-items/{owner_id}")
def read_direct_owned_item(owner_id: int, current_user: Student = Depends(require_owner_or_admin)):
    return {"owner_id": owner_id, "accessed_by": current_user.id}


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def seed_users():
    db = TestingSessionLocal()
    student = Student(
        email="student1@khi.iba.edu.pk",
        password_hash=hash_password("StrongPass123"),
        role="student",
        is_verified=True,
    )
    other_student = Student(
        email="student2@khi.iba.edu.pk",
        password_hash=hash_password("StrongPass123"),
        role="student",
        is_verified=True,
    )
    admin = Student(
        email="admin@khi.iba.edu.pk",
        password_hash=hash_password("StrongPass123"),
        role="admin",
        is_verified=True,
    )
    suspended = Student(
        email="suspended@khi.iba.edu.pk",
        password_hash=hash_password("StrongPass123"),
        role="student",
        is_verified=True,
        is_suspended=True,
    )
    db.add_all([student, other_student, admin, suspended])
    db.commit()
    for u in (student, other_student, admin, suspended):
        db.refresh(u)
    db.close()
    return {"student": student, "other": other_student, "admin": admin, "suspended": suspended}


client = TestClient(app)


def test_get_current_user_valid_token(seed_users):
    student = seed_users["student"]
    token = create_access_token(student.id, role=student.role)
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.json()["email"] == "student1@khi.iba.edu.pk"


def test_get_current_user_missing_or_invalid_token():
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer invalid.token.here"}).status_code == 401


def test_get_current_user_expired_token(seed_users):
    student = seed_users["student"]
    expired_token = create_access_token(student.id, expires_hours=-1)
    res = client.get("/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert res.status_code == 401


def test_suspended_user_forbidden(seed_users):
    suspended = seed_users["suspended"]
    token = create_access_token(suspended.id)
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 403


def test_require_admin_allows_admin_and_blocks_student(seed_users):
    student_token = create_access_token(seed_users["student"].id, role="student")
    admin_token = create_access_token(seed_users["admin"].id, role="admin")

    assert client.get("/admin-only", headers={"Authorization": f"Bearer {student_token}"}).status_code == 403
    assert client.get("/admin-only", headers={"Authorization": f"Bearer {admin_token}"}).status_code == 200


def test_owner_or_admin_access(seed_users):
    owner = seed_users["student"]
    other = seed_users["other"]
    admin = seed_users["admin"]

    owner_token = create_access_token(owner.id)
    other_token = create_access_token(other.id)
    admin_token = create_access_token(admin.id, role="admin")

    assert client.get(f"/items/{owner.id}", headers={"Authorization": f"Bearer {owner_token}"}).status_code == 200
    assert client.get(f"/items/{owner.id}", headers={"Authorization": f"Bearer {other_token}"}).status_code == 403
    assert client.get(f"/items/{owner.id}", headers={"Authorization": f"Bearer {admin_token}"}).status_code == 200