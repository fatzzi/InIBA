"""One-time codes for email verification.

SCRUM-19 only needs a code to be created and "sent". For now sending prints the code to the
server terminal so the flow can be tested locally. SCRUM-20 replaces send_otp_email() with a
real email provider and adds the resend / attempt limits (429).
"""

import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import OtpCode, Student
from app.security import hash_password


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


def send_otp_email(email: str, code: str) -> None:
    # TODO(SCRUM-20): send through the email provider instead of printing.
    print(f"[DEV] OTP for {email}: {code}", flush=True)
