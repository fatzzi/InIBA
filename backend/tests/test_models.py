import pytest
from sqlalchemy.exc import IntegrityError

from app.models import LocationTag, Post, Reaction, Report, Student


def _student(email: str) -> Student:
    return Student(email=email, password_hash="x", name=email.split("@")[0])


def test_post_with_author_and_zone(db_session):
    zone = LocationTag(zone_name="Library")
    author = _student("sara@khi.iba.edu.pk")
    db_session.add_all([zone, author])
    db_session.flush()
    post = Post(author_id=author.id, content="hi", location_tag_id=zone.id)
    db_session.add(post)
    db_session.commit()
    assert post.id is not None and post.is_removed is False and post.image_front is None


def test_one_reaction_per_student_per_post(db_session):
    s = _student("a@khi.iba.edu.pk")
    db_session.add(s)
    db_session.flush()
    p = Post(author_id=s.id, content="x")
    db_session.add(p)
    db_session.flush()
    db_session.add(Reaction(post_id=p.id, student_id=s.id, kind="heart"))
    db_session.commit()
    db_session.add(Reaction(post_id=p.id, student_id=s.id, kind="fire"))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_duplicate_report_rejected(db_session):
    a, b = _student("a@khi.iba.edu.pk"), _student("b@khi.iba.edu.pk")
    db_session.add_all([a, b])
    db_session.flush()
    p = Post(author_id=b.id, content="x")
    db_session.add(p)
    db_session.flush()
    db_session.add(Report(reporter_id=a.id, post_id=p.id, reason="spam"))
    db_session.commit()
    db_session.add(Report(reporter_id=a.id, post_id=p.id, reason="spam again"))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_email_must_be_unique(db_session):
    db_session.add(_student("dup@khi.iba.edu.pk"))
    db_session.commit()
    db_session.add(_student("dup@khi.iba.edu.pk"))
    with pytest.raises(IntegrityError):
        db_session.commit()
