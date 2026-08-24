from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import Field, field_validator, model_validator

from app.models.enums import (
    AmountMode,
    CampaignStatus,
    ContributionType,
    PaymentMethod,
)
from app.schemas.base import CamelModel


def _normalize(value: object) -> object:
    return value.strip().lower() if isinstance(value, str) else value


class CampaignCreate(CamelModel):
    """Nouvelle cotisation.

    `memberIds` absent vise **tous les membres actifs** ; une liste vide est
    refusée, parce qu'une cotisation sans destinataire n'a pas de sens et
    résulte presque toujours d'un formulaire mal renvoyé.
    """

    title: str = Field(min_length=2, max_length=180)
    description: str | None = Field(default=None, max_length=4000)
    contribution_type: ContributionType = ContributionType.ASSOCIATION
    amount: Decimal = Field(default=Decimal("0"), ge=0)
    amount_mode: AmountMode = AmountMode.FIXED
    currency: str = Field(default="XOF", max_length=8)
    start_date: datetime | None = None
    due_date: datetime | None = None
    member_ids: list[uuid.UUID] | None = None
    cashbox_id: uuid.UUID | None = None
    tontine_id: uuid.UUID | None = None
    mandatory: bool = True
    penalty_enabled: bool = False
    penalty_amount: Decimal = Field(default=Decimal("0"), ge=0)

    _normalize_enums = field_validator(
        "contribution_type", "amount_mode", mode="before"
    )(_normalize)

    @model_validator(mode="after")
    def _check_amount(self) -> CampaignCreate:
        if self.amount_mode is AmountMode.FIXED and self.amount <= 0:
            raise ValueError(
                "Une cotisation à montant fixe demande un montant supérieur à zéro."
            )
        if self.member_ids is not None and not self.member_ids:
            raise ValueError("Sélectionnez au moins un membre concerné.")
        return self


class CampaignUpdate(CamelModel):
    title: str | None = Field(default=None, min_length=2, max_length=180)
    description: str | None = Field(default=None, max_length=4000)
    due_date: datetime | None = None
    mandatory: bool | None = None
    penalty_enabled: bool | None = None
    penalty_amount: Decimal | None = Field(default=None, ge=0)
    status: CampaignStatus | None = None

    _normalize_status = field_validator("status", mode="before")(_normalize)


class CampaignPaymentCreate(CamelModel):
    """Règlement d'un membre pour une ligne de cotisation."""

    amount: Decimal = Field(gt=0)
    payment_method: PaymentMethod = PaymentMethod.CASH
    reference: str | None = Field(default=None, max_length=120)
    comment: str | None = Field(default=None, max_length=1000)
    proof_url: str | None = Field(default=None, max_length=512)
    paid_at: datetime | None = None

    _normalize_method = field_validator("payment_method", mode="before")(_normalize)


class CampaignPaymentCancel(CamelModel):
    reason: str | None = Field(default=None, max_length=500)


class CampaignExemption(CamelModel):
    reason: str | None = Field(default=None, max_length=500)
