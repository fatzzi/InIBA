from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import get_settings


class Base(DeclarativeBase):
    pass


def _make_engine(url: str):
    if url.startswith("sqlite"):
        return create_engine(url, connect_args={"check_same_thread": False})
    # Supabase's free session pooler allows ~15 client connections. The public API takes up to 10, leaving room
    # for a developer laptop or the seed script. pre_ping drops connections the host closed.
    return create_engine(url, pool_pre_ping=True, pool_size=5, max_overflow=5, pool_recycle=300)


engine = _make_engine(get_settings().database_url)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
