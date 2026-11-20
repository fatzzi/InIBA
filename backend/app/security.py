"""Password hashing with bcrypt and JWT authentication / role dependencies (SCRUM-21/23)."""

from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Student

# bcrypt only looks at the first 72 bytes of a password; longer ones are rejected at the schema.
BCRYPT_MAX_BYTES = 72
JWT_ALGORITHM = "HS256"

bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(student_id: int, role: str = "student", expires_hours: int | None = None) -> str:
    settings = get_settings()
    expire_delta = timedelta(hours=expires_hours if expires_hours is not None else settings.jwt_expire_hours)
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(student_id),
        "role": role,
        "iat": now,
        "exp": now + expire_delta,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    settings = get_settings()
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication token")


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Student:
    if credentials is None or credentials.scheme.lower() != "bearer" or not credentials.credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authentication token")

    payload = decode_access_token(credentials.credentials)
    sub = payload.get("sub")
    if sub is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")

    try:
        student_id = int(sub)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")

    student = db.get(Student, student_id)
    if student is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if student.is_suspended:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is suspended")

    return student


def require_admin(current_user: Student = Depends(get_current_user)) -> Student:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


def ensure_owner_or_admin(owner_id: int, current_user: Student) -> None:
    """Call inside route handlers once the target resource (e.g., Post, Highlight) is loaded."""
    if current_user.role != "admin" and current_user.id != owner_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to access this resource")


def require_owner_or_admin(owner_id: int):
    """Dependency factory when owner_id is passed directly as a path/query parameter."""

    def _checker(current_user: Student = Depends(get_current_user)) -> Student:
        ensure_owner_or_admin(owner_id, current_user)
        return current_user

    return _checker