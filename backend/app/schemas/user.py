from __future__ import annotations

import uuid
from datetime import date, datetime

from pydantic import EmailStr, Field

from app.models.enums import Gender
from app.schemas.base import CamelModel


class UserRead(CamelModel):
    """Objet `user` du contrat d'API. Ne contient jamais le mot de passe."""

    id: uuid.UUID
    first_name: str
    last_name: str
    phone: str
    email: str | None = None
    avatar_url: str | None = None
    gender: Gender = Gender.UNSPECIFIED
    birth_date: date | None = None
    created_at: datetime


class UserUpdate(CamelModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=120)
    last_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, min_length=4, max_length=32)
    email: EmailStr | None = None
    avatar_url: str | None = None
    gender: Gender | None = None
    birth_date: date | None = None
