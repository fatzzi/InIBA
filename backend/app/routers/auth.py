"""E1 authentication endpoints (API doc section 2)."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Student
from app.otp import enforce_resend_cooldown, issue_otp, send_otp_email
from app.schemas.auth import RegisterRequest, RegisterResponse, ResendOtpRequest, ResendOtpResponse
from app.security import hash_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=status.HTTP_201_CREATED, response_model=RegisterResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    """SCRUM-19. Create a pending (unverified) account and send a 6-digit OTP.

    - non-IBA email, short password, mismatched passwords -> 400 (schema validation)
    - email already belongs to a verified account -> 409
    - email belongs to a pending account that never verified -> that account is reused with the
      new password/name and a fresh OTP, so the student is not locked out (API doc 2.1)
    """
    student = db.scalar(select(Student).where(Student.email == body.email))

    if student is not None and student.is_verified:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already registered")

    if student is None:
        student = Student(email=body.email, password_hash=hash_password(body.password), name=body.name)
        db.add(student)
    else:
        student.password_hash = hash_password(body.password)
        student.name = body.name
    db.flush()  # assigns student.id so the OTP row can reference it

    code = issue_otp(db, student)
    db.commit()

    send_otp_email(student.email, code)
    return RegisterResponse(
        message=f"OTP sent to {student.email}",
        expires_in_minutes=get_settings().otp_expire_minutes,
    )


@router.post("/resend-otp", response_model=ResendOtpResponse)
def resend_otp(body: ResendOtpRequest, db: Session = Depends(get_db)) -> ResendOtpResponse:
    """SCRUM-20. 404 unknown account, 409 already verified, 429 too soon, 200 fresh code sent."""
    student = db.scalar(select(Student).where(Student.email == body.email))
    if student is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Account not found")
    if student.is_verified:
        raise HTTPException(status.HTTP_409_CONFLICT, "Account already verified")

    enforce_resend_cooldown(db, student)  # before issue_otp deletes the old code
    code = issue_otp(db, student)
    db.commit()

    send_otp_email(student.email, code)
    return ResendOtpResponse(
        message=f"OTP sent to {student.email}",
        expires_in_minutes=get_settings().otp_expire_minutes,
    )