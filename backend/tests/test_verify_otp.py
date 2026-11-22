"""Tests for SCRUM-21: POST /auth/verify."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.models import OtpCode, Student
from app.security import decode_access_token

EMAIL = "alice@khi.iba.edu.pk"


def _register_and_get_code(client, capsys, email: str = EMAIL, name: str = "Alice Khan") -> str:
    res = client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "StrongPassword1!",
            "confirmPassword": "StrongPassword1!",
            "name": name,
        },
    )
    assert res.status_code == 201
    out = capsys.readouterr().out
    # Dev fallback prints: "[DEV] OTP for <email>: <6-digit-code>"
    for line in reversed(out.splitlines()):
        if "[DEV] OTP for" in line:
            return line.rsplit(":", 1)[1].strip()
    pytest.fail("Could not find dev OTP output in stdout")


def test_verify_otp_success_issues_jwt_and_activates_student(client, db_session, capsys):
    code = _register_and_get_code(client, capsys)

    res = client.post("/auth/verify", json={"email": EMAIL, "code": code})
    assert res.status_code == 200
    body = res.json()

    assert "token" in body
    assert body["expiresIn"] == 86400
    assert body["student"]["name"] == "Alice Khan"
    assert body["student"]["batch"] is None
    assert body["student"]["department"] is None
    assert body["student"]["profilePhoto"] is None

    # Token decodes to this student's ID and role
    student = db_session.scalar(select(Student).where(Student.email == EMAIL))
    assert student is not None
    assert student.is_verified is True

    payload = decode_access_token(body["token"])
    assert payload["sub"] == str(student.id)
    assert payload["role"] == "student"

    # Used OTP row is deleted so it cannot be replayed
    remaining_otps = db_session.scalars(select(OtpCode).where(OtpCode.student_id == student.id)).all()
    assert remaining_otps == []


def test_verify_otp_cannot_replay_used_code(client, capsys):
    code = _register_and_get_code(client, capsys)

    first = client.post("/auth/verify", json={"email": EMAIL, "code": code})
    assert first.status_code == 200

    # Account is now verified (no longer pending), so second attempt returns 404
    second = client.post("/auth/verify", json={"email": EMAIL, "code": code})
    assert second.status_code == 404


def test_verify_otp_unknown_email_returns_404(client):
    res = client.post("/auth/verify", json={"email": "nobody@khi.iba.edu.pk", "code": "123456"})
    assert res.status_code == 404


def test_verify_otp_wrong_code_increments_attempts_and_locks_at_5(client, db_session, capsys):
    code = _register_and_get_code(client, capsys)
    wrong_code = "000000" if code != "000000" else "999999"

    # First 4 wrong attempts return 400
    for expected_attempt in range(1, 5):
        res = client.post("/auth/verify", json={"email": EMAIL, "code": wrong_code})
        assert res.status_code == 400
        otp = db_session.scalar(select(OtpCode))
        assert otp is not None
        assert otp.attempts == expected_attempt

    # 5th wrong attempt hits max attempts (5) and returns 429
    fifth = client.post("/auth/verify", json={"email": EMAIL, "code": wrong_code})
    assert fifth.status_code == 429

    # Even the real code is now blocked with 429 until user requests a fresh OTP
    sixth = client.post("/auth/verify", json={"email": EMAIL, "code": code})
    assert sixth.status_code == 429


def test_verify_otp_expired_code_returns_400(client, db_session, capsys):
    code = _register_and_get_code(client, capsys)

    otp = db_session.scalar(select(OtpCode))
    assert otp is not None
    otp.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db_session.commit()

    res = client.post("/auth/verify", json={"email": EMAIL, "code": code})
    assert res.status_code == 400
    assert "expired" in res.json()["message"].lower()


def test_verify_otp_malformed_code_or_non_iba_email_returns_400(client):
    # Non-IBA domain
    r1 = client.post("/auth/verify", json={"email": "alice@gmail.com", "code": "123456"})
    assert r1.status_code == 400

    # Non-digit or wrong length code
    r2 = client.post("/auth/verify", json={"email": EMAIL, "code": "12345"})
    assert r2.status_code == 400

    r3 = client.post("/auth/verify", json={"email": EMAIL, "code": "abcdef"})
    assert r3.status_code == 400