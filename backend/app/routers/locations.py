"""GET /locations (API doc 4.6; SCRUM-29): the preset campus zones used for tagging posts, feed filters and Spotted at."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import LocationTag, Student
from app.schemas.posts import LocationTagOut, Zones
from app.security import get_current_user

router = APIRouter(prefix="/locations", tags=["feed"])


@router.get("", response_model=Zones, response_model_by_alias=True)
def list_locations(_: Student = Depends(get_current_user), db: Session = Depends(get_db)) -> Zones:
    """Every preset zone, in id order. Zones are created by `python -m scripts.seed`."""
    tags = db.scalars(select(LocationTag).order_by(LocationTag.id)).all()
    return Zones(items=[LocationTagOut(tag_id=t.id, zone_name=t.zone_name) for t in tags])
