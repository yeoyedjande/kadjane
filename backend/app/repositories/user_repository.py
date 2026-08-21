from __future__ import annotations

import uuid

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    """Accès aux utilisateurs. Aucune règle métier ici."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def by_id(self, user_id: uuid.UUID) -> User | None:
        return self.db.get(User, user_id)

    def by_identifier(self, identifier: str) -> User | None:
        """Recherche par téléphone ou e-mail, insensible à la casse."""
        value = identifier.strip()
        normalized = _normalize_phone(value)
        statement = select(User).where(
            or_(
                func.lower(User.email) == value.lower(),
                User.phone == value,
                func.replace(
                    func.replace(func.replace(User.phone, " ", ""), "-", ""), ".", ""
                )
                == normalized,
            )
        )
        return self.db.scalars(statement).first()

    def by_phone(self, phone: str) -> User | None:
        normalized = _normalize_phone(phone)
        statement = select(User).where(
            func.replace(
                func.replace(func.replace(User.phone, " ", ""), "-", ""), ".", ""
            )
            == normalized
        )
        return self.db.scalars(statement).first()

    def by_email(self, email: str) -> User | None:
        statement = select(User).where(func.lower(User.email) == email.strip().lower())
        return self.db.scalars(statement).first()

    def add(self, user: User) -> User:
        self.db.add(user)
        self.db.flush()
        return user


def _normalize_phone(value: str) -> str:
    return value.replace(" ", "").replace("-", "").replace(".", "").strip()
