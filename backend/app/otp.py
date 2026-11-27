"""One-time codes for email verification.

SCRUM-19 creates and hashes the 6-digit code. SCRUM-20 sends it via SMTP (with a
dev print fallback when SMTP_HOST is empty) and enforces the resend cooldown (429).
"""

import math
import secrets
import smtplib
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

from fastapi import HTTPException
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import OtpCode, Student
from app.security import hash_password, verify_password

def generate_code() -> str:
    """6-digit code from a cryptographically secure source (not random.randint)."""
    return f"{secrets.randbelow(1_000_000):06d}"


def issue_otp(db: Session, student: Student) -> str:
    """Invalidate any previous codes for this student and store a fresh hashed one. Returns the plain code."""
    db.execute(delete(OtpCode).where(OtpCode.student_id == student.id))
    code = generate_code()
    db.add(
        OtpCode(
            student_id=student.id,
            code_hash=hash_password(code),  # stored hashed, like a password
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=get_settings().otp_expire_minutes),
            attempts=0,
        )
    )
    return code


def as_utc(value: datetime) -> datetime:
    """Public on purpose: SCRUM-21 imports it.

    SQLite returns datetimes without a timezone; PostgreSQL returns them with one.
    Comparing the two kinds raises an error, so attach UTC when it's missing.
    """
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def enforce_resend_cooldown(db: Session, student: Student) -> None:
    """Raise 429 if the latest code was issued too recently.

    Must run BEFORE issue_otp, which deletes the old row this check reads.
    """
    cooldown = get_settings().otp_resend_cooldown_seconds
    latest = db.scalar(
        select(OtpCode)
        .where(OtpCode.student_id == student.id)
        .order_by(OtpCode.created_at.desc())
        .limit(1)
    )
    if latest is None:
        return
    elapsed = (datetime.now(timezone.utc) - as_utc(latest.created_at)).total_seconds()
    if elapsed < cooldown:
        wait = math.ceil(cooldown - elapsed)
        raise HTTPException(429, f"Please wait {wait} seconds before requesting another code")



def verify_otp_code(db: Session, student: Student, code: str) -> None:
    """SCRUM-21. Validate the 6-digit code, track failed attempts, and delete on success."""
    settings = get_settings()
    otp = db.scalar(
        select(OtpCode)
        .where(OtpCode.student_id == student.id)
        .order_by(OtpCode.created_at.desc())
        .limit(1)
    )
    if otp is None:
        raise HTTPException(400, "No active verification code; request a new one")

    if otp.attempts >= settings.otp_max_attempts:
        raise HTTPException(429, "Too many failed attempts; please request a new code")

    if as_utc(otp.expires_at) <= datetime.now(timezone.utc):
        db.delete(otp)
        db.commit()
        raise HTTPException(400, "Verification code has expired")

    if not verify_password(code, otp.code_hash):
        otp.attempts += 1
        db.commit()
        if otp.attempts >= settings.otp_max_attempts:
            raise HTTPException(429, "Too many failed attempts; please request a new code")
        raise HTTPException(400, "Invalid verification code")

    db.delete(otp)
def send_otp_email(email: str, code: str) -> None:
    settings = get_settings()
    if not settings.smtp_host:
        # Keep this exact format: the code must be the last word on the line (an existing test parses it).
        print(f"[DEV] OTP for {email}: {code}", flush=True)
        return

    message = EmailMessage()
    message["Subject"] = "Your InIBA verification code"
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message.set_content(
        f"Your InIBA verification code is {code}. It expires in {settings.otp_expire_minutes} minutes."
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            if settings.smtp_use_tls:
                server.starttls()
            if settings.smtp_username:
                server.login(settings.smtp_username, settings.smtp_password)
            server.send_message(message)
    except (smtplib.SMTPException, OSError):
        # Never put the raw error or the password in the response; the API doc wants {code, message}.
        raise HTTPException(503, "Could not send verification email")


