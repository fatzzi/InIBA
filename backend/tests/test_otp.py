import smtplib
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from fastapi import HTTPException
from sqlalchemy import select

from app.models import OtpCode, Student
from app.otp import send_otp_email

GOOD = {
    "email": "student@khi.iba.edu.pk",
    "password": "S3cure!pass",
    "confirmPassword": "S3cure!pass",
    "name": "Student Name",
}

SMTP_SETTINGS = SimpleNamespace(
    smtp_host="smtp.test",
    smtp_port=587,
    smtp_username="user",
    smtp_password="pw",
    smtp_from_email="no-reply@test",
    smtp_use_tls=True,
    otp_expire_minutes=10,
)


def test_send_otp_email_uses_smtp():
    with patch("app.otp.get_settings", return_value=SMTP_SETTINGS), patch("app.otp.smtplib.SMTP") as smtp:
        send_otp_email("a@khi.iba.edu.pk", "123456")
    server = smtp.return_value.__enter__.return_value
    server.starttls.assert_called_once()
    server.login.assert_called_once_with("user", "pw")
    server.send_message.assert_called_once()
    assert "123456" in server.send_message.call_args.args[0].get_content()


def test_send_otp_email_prints_when_no_smtp_host(capsys):
    send_otp_email("a@khi.iba.edu.pk", "654321")
    assert capsys.readouterr().out.strip() == "[DEV] OTP for a@khi.iba.edu.pk: 654321"


def test_smtp_failure_returns_503():
    with (
        patch("app.otp.get_settings", return_value=SMTP_SETTINGS),
        patch("app.otp.smtplib.SMTP", side_effect=smtplib.SMTPException("boom")),
    ):
        with pytest.raises(HTTPException) as err:
            send_otp_email("a@khi.iba.edu.pk", "123456")
    assert err.value.status_code == 503


def test_resend_unknown_account_404(client):
    res = client.post("/auth/resend-otp", json={"email": "nobody@khi.iba.edu.pk"})
    assert res.status_code == 404


def test_resend_verified_account_409(client, db_session):
    client.post("/auth/register", json=GOOD)
    db_session.scalar(select(Student)).is_verified = True
    db_session.commit()
    assert client.post("/auth/resend-otp", json={"email": GOOD["email"]}).status_code == 409


def test_resend_within_cooldown_429(client):
    client.post("/auth/register", json=GOOD)
    with patch("app.routers.auth.send_otp_email"):
        res = client.post("/auth/resend-otp", json={"email": GOOD["email"]})
    assert res.status_code == 429
    assert res.json()["code"] == 429


def test_resend_after_cooldown_rotates_code(client, db_session):
    client.post("/auth/register", json=GOOD)
    row = db_session.scalar(select(OtpCode))
    old_hash = row.code_hash
    row.created_at = datetime.now(timezone.utc) - timedelta(seconds=120)  # backdate, no sleep
    db_session.commit()

    with patch("app.routers.auth.send_otp_email") as sender:
        res = client.post("/auth/resend-otp", json={"email": GOOD["email"]})
    assert res.status_code == 200
    assert res.json()["expiresInMinutes"] == 10
    sender.assert_called_once()

    rows = db_session.scalars(select(OtpCode)).all()
    assert len(rows) == 1 and rows[0].code_hash != old_hash