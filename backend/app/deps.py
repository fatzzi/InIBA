"""Request dependencies shared by routers.

`get_current_student` is a minimal stand-in until SCRUM-23 (JWT auth) lands; that story can replace the
body of this function without touching the routers. Tokens are HS256 JWTs signed with `settings.jwt_secret`
whose `sub` claim is the student id.
"""

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Student

_bearer = HTTPBearer(auto_error=False)


def get_current_student(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> Student:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(401, "Missing bearer token")
    try:
        payload = jwt.decode(creds.credentials, get_settings().jwt_secret, algorithms=["HS256"])
        student_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        raise HTTPException(401, "Invalid or expired token")

    student = db.get(Student, student_id)
    if student is None or not student.is_verified:
        raise HTTPException(401, "Invalid or expired token")
    if student.is_suspended:
        raise HTTPException(403, "Account suspended")
    return student
