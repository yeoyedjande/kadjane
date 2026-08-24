from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator

from app.models.enums import TransactionCategory, TransactionType
from app.schemas.base import CamelModel


def _normalize(value: object) -> object:
    return value.strip().lower() if isinstance(value, str) else value


class TransactionCreate(CamelModel):
    """Mouvement de caisse saisi à la main (don, frais, événement…)."""

    type: TransactionType = TransactionType.INCOME
    category: TransactionCategory = TransactionCategory.OTHER
    amount: Decimal = Field(gt=0)
    date: datetime | None = None
    description: str | None = Field(default=None, max_length=500)
    tontine_id: uuid.UUID | None = None
    proof_url: str | None = Field(default=None, max_length=512)

    _normalize_enums = field_validator("type", "category", mode="before")(_normalize)


class DeviceRegistration(CamelModel):
    token: str = Field(min_length=8, max_length=512)
    platform: str = Field(default="unknown", max_length=20)


class DeviceUnregistration(CamelModel):
    token: str = Field(min_length=8, max_length=512)
