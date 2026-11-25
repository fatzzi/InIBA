"""Open today's IBA Moment right now for every student, for demos and manual testing. Local development only.

Usage (from backend/):  python -m scripts.open_moment [seconds]    (default: the configured 120)
"""

import sys
from datetime import timedelta

from sqlalchemy import select

from app.config import get_settings
from app.db import SessionLocal
from app.models import Student
from app.services.moments import utc_now, window_for_today


def main() -> None:
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else get_settings().moment_duration_seconds
    now = utc_now()
    with SessionLocal() as db:
        for student in db.scalars(select(Student)).all():
            window = window_for_today(db, student, now)
            window.opens_at, window.closes_at = now, now + timedelta(seconds=seconds)
        db.commit()
    print(f"IBA Moment open for {seconds} seconds.")


if __name__ == "__main__":
    main()
