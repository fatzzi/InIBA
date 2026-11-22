"""SCRUM-19 acceptance: non-IBA domain 400, duplicate 409, bcrypt hash, pending account + OTP created."""

from sqlalchemy import select

from app.models import OtpCode, Student
from app.security import verify_password

GOOD = {
    "email": "student@khi.iba.edu.pk",
    "password": "S3cure!pass",
    "confirmPassword": "S3cure!pass",
    "name": "Student Name",
}


def register(client, **overrides):
    return client.post("/auth/register", json={**GOOD, **overrides})


def test_register_creates_pending_account_and_otp(client, db_session):
    res = register(client)
    assert res.status_code == 201
    assert res.json() == {"message": "OTP sent to student@khi.iba.edu.pk", "expiresInMinutes": 10}

    student = db_session.scalar(select(Student).where(Student.email == GOOD["email"]))
    assert student is not None
    assert student.is_verified is False
    assert student.name == "Student Name"
    assert student.password_hash != GOOD["password"]
    assert verify_password(GOOD["password"], student.password_hash)

    otps = db_session.scalars(select(OtpCode).where(OtpCode.student_id == student.id)).all()
    assert len(otps) == 1


def test_register_prints_six_digit_code(client, capsys):
    register(client)
    out = capsys.readouterr().out
    code = out.strip().rsplit(" ", 1)[-1]
    assert len(code) == 6 and code.isdigit()


def test_email_is_normalised(client, db_session):
    assert register(client, email="  Student@KHI.IBA.EDU.PK ").status_code == 201
    assert db_session.scalar(select(Student.email)) == "student@khi.iba.edu.pk"


def test_non_iba_domain_rejected(client):
    for email in ["someone@gmail.com", "x@iba.edu.pk", "x@khi.iba.edu.pk.evil.com"]:
        res = register(client, email=email)
        assert res.status_code == 400, email
        assert res.json()["code"] == 400


def test_password_mismatch_rejected(client):
    res = register(client, confirmPassword="different1")
    assert res.status_code == 400
    assert "do not match" in res.json()["message"]


def test_short_password_rejected(client):
    assert register(client, password="short", confirmPassword="short").status_code == 400


def test_blank_name_rejected(client):
    assert register(client, name="   ").status_code == 400


def test_missing_field_rejected(client):
    body = dict(GOOD)
    del body["name"]
    assert client.post("/auth/register", json=body).status_code == 400


def test_duplicate_verified_email_conflict(client, db_session):
    register(client)
    student = db_session.scalar(select(Student))
    student.is_verified = True
    db_session.commit()

    res = register(client)
    assert res.status_code == 409
    assert res.json() == {"code": 409, "message": "Email already registered"}


def test_pending_account_is_replaced_not_duplicated(client, db_session):
    register(client)
    res = register(client, password="NewPass123", confirmPassword="NewPass123", name="New Name")
    assert res.status_code == 201

    students = db_session.scalars(select(Student)).all()
    assert len(students) == 1
    assert students[0].name == "New Name"
    assert verify_password("NewPass123", students[0].password_hash)
    # the old code is invalidated, only the fresh one remains
    assert len(db_session.scalars(select(OtpCode)).all()) == 1
