"""GET /moments/current (API doc 4.2; SCRUM-42)."""

from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Student
from app.schemas.moments import MomentStatus
from app.security import get_current_user
from app.services import moments as svc

router = APIRouter(prefix="/moments", tags=["moments"])


@router.get("/current", response_model=MomentStatus, response_model_by_alias=True)
def current_moment(
    me: Student = Depends(get_current_user),
    db: Session = Depends(get_db),
    now: datetime = Depends(svc.utc_now),
) -> MomentStatus:
    """Is the IBA Moment open, how many seconds are left, and has the caller posted today."""
    return svc.status(db, me, now)
