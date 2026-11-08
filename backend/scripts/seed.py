"""Seed campus zones and societies. With SEED_PASSWORD set, also create an admin and sample students.

Usage (from backend/):  python -m scripts.seed
Safe to re-run: existing rows are skipped.
"""

import os

import bcrypt
from sqlalchemy import select

from app.config import get_settings
from app.db import SessionLocal
from app.models import LocationTag, Society, Student

ZONES = ["Library", "CED", "AMAN Tower", "Hostel", "Sports Complex", "Cafeteria", "Main Gate"]
SOCIETIES = ["Debating Society", "Drama Society", "IEEE", "Music Society", "Entrepreneurship Club"]
SAMPLE_STUDENTS = [
    ("sara.a", "Sara A.", "2027", "Business"),
    ("hamza.k", "Hamza K.", "2026", "Computer Science"),
    ("ayesha.r", "Ayesha R.", "2028", "Economics"),
]


def seed() -> None:
    settings = get_settings()
    password = os.environ.get("SEED_PASSWORD", "")
    admin_email = os.environ.get("SEED_ADMIN_EMAIL", f"admin@{settings.allowed_email_domain}")

    with SessionLocal() as db:
        for zone in ZONES:
            if not db.scalar(select(LocationTag).where(LocationTag.zone_name == zone)):
                db.add(LocationTag(zone_name=zone))
        for name in SOCIETIES:
            if not db.scalar(select(Society).where(Society.name == name)):
                db.add(Society(name=name))

        if password:
            hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
            people = [(admin_email, "Admin", None, None, "admin")] + [
                (f"{handle}@{settings.allowed_email_domain}", name, batch, dept, "student")
                for handle, name, batch, dept in SAMPLE_STUDENTS
            ]
            for email, name, batch, dept, role in people:
                if not db.scalar(select(Student).where(Student.email == email)):
                    db.add(
                        Student(
                            email=email, password_hash=hashed, name=name, batch=batch,
                            department=dept, role=role, is_verified=True,
                        )
                    )
        else:
            print("SEED_PASSWORD not set: seeded zones and societies only.")
        db.commit()
    print("Seed complete.")


if __name__ == "__main__":
    seed()
