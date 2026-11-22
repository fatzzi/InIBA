"""Seed campus zones and societies. With SEED_PASSWORD set, also create an admin and sample students,
and give the first sample student a filled-in profile with a few posts (for the profile screen).

Usage (from backend/):  python -m scripts.seed
Safe to re-run: existing rows are skipped.
"""

import os
from datetime import datetime, timedelta, timezone

import bcrypt
from sqlalchemy import select

from app.config import get_settings
from app.db import SessionLocal
from app.models import LocationTag, Post, Society, Student

ZONES = ["Library", "CED", "AMAN Tower", "Hostel", "Sports Complex", "Cafeteria", "Main Gate"]
SOCIETIES = ["Debating Society", "Drama Society", "IEEE", "Music Society", "Entrepreneurship Club"]
SAMPLE_STUDENTS = [
    ("sara.a", "Sara A.", "2027", "Business"),
    ("hamza.k", "Hamza K.", "2026", "Computer Science"),
    ("ayesha.r", "Ayesha R.", "2028", "Economics"),
]
SAMPLE_PROFILE = {
    "bio": "need coffee before 9am classes",
    "mood_sticker": "sleepy",
    "tags": ["need coffee", "library regular", "night owl"],
    "societies": ["Debating Society", "IEEE"],
    "posts": [  # (days ago, text); consecutive days give a streak of 3
        (0, "Library grind before midterms"),
        (1, "Chai at the cafeteria with the group"),
        (2, "Debate practice ran late again"),
        (5, "First day of the semester!"),
    ],
}


def _seed_profile(db, student: Student) -> None:
    if student.bio:  # already seeded
        return
    student.bio = SAMPLE_PROFILE["bio"]
    student.mood_sticker = SAMPLE_PROFILE["mood_sticker"]
    student.mood_set_at = datetime.now(timezone.utc)
    student.tags = SAMPLE_PROFILE["tags"]
    student.societies = list(db.scalars(select(Society).where(Society.name.in_(SAMPLE_PROFILE["societies"]))))
    now = datetime.now(timezone.utc)
    for days_ago, text in SAMPLE_PROFILE["posts"]:
        db.add(Post(author_id=student.id, content=text, created_at=now - timedelta(days=days_ago)))


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
            db.flush()
            first_email = f"{SAMPLE_STUDENTS[0][0]}@{settings.allowed_email_domain}"
            _seed_profile(db, db.scalar(select(Student).where(Student.email == first_email)))
        else:
            print("SEED_PASSWORD not set: seeded zones and societies only.")
        db.commit()
    print("Seed complete.")


if __name__ == "__main__":
    seed()
