"""Moteur, fabrique de sessions et dépendance FastAPI `get_db`."""

from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


def build_engine(url: str | None = None) -> Engine:
    database_url = url or settings.database_url
    kwargs: dict[str, object] = {"pool_pre_ping": True, "future": True}
    if database_url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
    else:
        kwargs["pool_size"] = 5
        kwargs["max_overflow"] = 10
    return create_engine(database_url, **kwargs)


engine: Engine = build_engine()

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """Session par requête : commit implicite laissé aux services."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
