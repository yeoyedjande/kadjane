"""Schémas des cotisations de caisse."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import Field

from app.models.enums import (
    ContributionStatus,
    DuesPlanStatus,
    PaymentMethod,
    PaymentStatus,
    TontineFrequency,
)
from app.schemas.base import CamelModel
from app.schemas.member import MemberRead


class DuesPlanCreate(CamelModel):
    """Création d'une cotisation périodique.

    `startDate` fixe le début de la première période ; omis, le mois courant.
    Le montant est le même pour tous les membres — c'est le principe d'une
    caisse commune.
    """

    name: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(gt=0)
    description: str | None = None
    currency: str = Field(default="XOF", max_length=8)
    frequency: TontineFrequency = TontineFrequency.MONTHLY
    due_day: int = Field(default=5, ge=1, le=31)
    custom_period_days: int | None = Field(default=None, ge=1, le=365)
    start_date: date | None = None


class DuesPlanUpdate(CamelModel):
    """Mise à jour d'un plan.

    Un changement de montant ne vaut que pour les périodes **à venir** : les
    échéances déjà engendrées gardent le leur, sous peine de fausser les
    comptes du trésorier.
    """

    name: str | None = Field(default=None, min_length=1, max_length=120)
    amount: Decimal | None = Field(default=None, gt=0)
    description: str | None = None
    due_day: int | None = Field(default=None, ge=1, le=31)
    status: DuesPlanStatus | None = None


class DuesPlanRead(CamelModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    name: str
    description: str | None = None
    amount: Decimal
    currency: str
    frequency: TontineFrequency
    due_day: int
    custom_period_days: int | None = None
    start_date: date
    status: DuesPlanStatus
    created_at: datetime


class DuesPaymentRead(CamelModel):
    id: uuid.UUID
    entry_id: uuid.UUID
    amount: Decimal
    payment_method: PaymentMethod
    reference: str | None = None
    comment: str | None = None
    proof_url: str | None = None
    status: PaymentStatus
    paid_at: datetime | None = None
    cancelled_at: datetime | None = None
    cancel_reason: str | None = None


class DuesEntryRead(CamelModel):
    """Ce qu'un membre doit pour une période."""

    id: uuid.UUID
    organization_id: uuid.UUID
    plan_id: uuid.UUID
    member_id: uuid.UUID
    member: MemberRead | None = None
    sequence_number: int
    period_label: str
    period_start: datetime
    period_end: datetime
    due_date: datetime
    expected_amount: Decimal
    paid_amount: Decimal
    remaining_amount: Decimal
    status: ContributionStatus


class DuesPaymentCreate(CamelModel):
    amount: Decimal = Field(gt=0)
    payment_method: PaymentMethod = PaymentMethod.CASH
    reference: str | None = Field(default=None, max_length=120)
    comment: str | None = None
    proof_url: str | None = Field(default=None, max_length=512)
    paid_at: datetime | None = None


class DuesPaymentCancel(CamelModel):
    reason: str = Field(min_length=3, max_length=500)
