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


class CashboxCreate(CamelModel):
    """Ouverture d'une caisse."""

    name: str = Field(min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    currency: str = Field(default="XOF", max_length=8)
    opening_balance: Decimal = Field(default=Decimal("0"), ge=0)
    is_default: bool = False


class CashboxUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    is_default: bool | None = None


class CashTransactionCreate(CamelModel):
    """Mouvement saisi dans une caisse identifiée.

    `TRANSFER` et `ADJUSTMENT` s'ajoutent aux entrées et sorties : le premier
    déplace des fonds entre deux caisses, le second corrige un écart constaté.
    """

    type: TransactionType = TransactionType.INCOME
    category: TransactionCategory = TransactionCategory.OTHER
    amount: Decimal
    date: datetime | None = None
    description: str | None = Field(default=None, max_length=500)
    reference: str | None = Field(default=None, max_length=120)
    tontine_id: uuid.UUID | None = None
    proof_url: str | None = Field(default=None, max_length=512)

    _normalize_enums = field_validator("type", "category", mode="before")(_normalize)


class CashTransactionCancel(CamelModel):
    reason: str | None = Field(default=None, max_length=500)
    # Contrepassation plutôt qu'annulation : l'écriture était valide, elle est
    # neutralisée par une décision, pas corrigée d'une erreur de saisie.
    reversed: bool = False
