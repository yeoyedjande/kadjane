"""Schémas d'entrée du métier tontine.

Les corps de requête acceptent indifféremment le camelCase de l'application
mobile (`contributionAmount`, `allocationMode`) et le snake_case du cahier des
charges (`contribution_amount`, `attribution_mode`), ainsi que les valeurs
d'énumération en majuscules (`MONTHLY_DRAW`).
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import Field, field_validator, model_validator

from app.models.enums import (
    AllocationMode,
    ContributionStatus,
    PaymentMethod,
    PaymentStatus,
    PayoutStatus,
    TontineFrequency,
    TontineStatus,
)
from app.schemas.base import CamelModel


def _normalize(value: object) -> object:
    """`MONTHLY_DRAW` -> `monthly_draw`."""
    return value.strip().lower() if isinstance(value, str) else value


class TontineCreate(CamelModel):
    name: str = Field(min_length=2, max_length=180)
    contribution_amount: Decimal = Field(gt=0)
    currency: str = Field(default="XOF", min_length=3, max_length=3)
    frequency: TontineFrequency = TontineFrequency.MONTHLY
    attribution_mode: AllocationMode = Field(
        default=AllocationMode.MONTHLY_DRAW,
        validation_alias="allocationMode",
        serialization_alias="allocationMode",
    )
    start_date: date
    due_day: int = Field(
        default=5, ge=1, le=31, validation_alias="dueDayOfPeriod"
    )
    description: str | None = None
    custom_period_days: int | None = Field(default=None, ge=1, le=365)
    participant_ids: list[uuid.UUID] = Field(
        default_factory=list, validation_alias="memberIds"
    )
    manual_order: list[uuid.UUID] = Field(default_factory=list)
    require_all_contributions_before_draw: bool = True
    allow_draw_override: bool = True
    activate: bool = True

    _normalize_enums = field_validator(
        "frequency", "attribution_mode", mode="before"
    )(_normalize)

    @model_validator(mode="before")
    @classmethod
    def _accept_both_conventions(cls, data: object) -> object:
        """Tolère les deux jeux de noms côté client."""
        if not isinstance(data, dict):
            return data
        pairs = (
            ("contribution_amount", "contributionAmount"),
            ("start_date", "startDate"),
            ("due_day", "dueDayOfPeriod"),
            ("due_day", "due_day"),
            ("attribution_mode", "allocationMode"),
            ("attribution_mode", "attribution_mode"),
            ("participant_ids", "memberIds"),
            ("participant_ids", "participant_ids"),
            ("manual_order", "manualOrder"),
            ("custom_period_days", "customPeriodDays"),
            ("require_all_contributions_before_draw", "requireAllContributionsBeforeDraw"),
            ("allow_draw_override", "allowDrawOverride"),
        )
        merged = dict(data)
        for target, source in pairs:
            if merged.get(target) is None and merged.get(source) is not None:
                merged[target] = merged[source]
        return merged


class TontineUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=2, max_length=180)
    description: str | None = None
    due_day: int | None = Field(default=None, ge=1, le=31)
    status: TontineStatus | None = None
    require_all_contributions_before_draw: bool | None = None
    allow_draw_override: bool | None = None
    contribution_amount: Decimal | None = Field(default=None, gt=0)

    _normalize_status = field_validator("status", mode="before")(_normalize)

    @model_validator(mode="before")
    @classmethod
    def _accept_both_conventions(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data
        merged = dict(data)
        aliases = {
            "due_day": "dueDayOfPeriod",
            "contribution_amount": "contributionAmount",
            "require_all_contributions_before_draw": "requireAllContributionsBeforeDraw",
            "allow_draw_override": "allowDrawOverride",
        }
        for target, source in aliases.items():
            if merged.get(target) is None and merged.get(source) is not None:
                merged[target] = merged[source]
        return merged


class StatusChange(CamelModel):
    status: TontineStatus

    _normalize_status = field_validator("status", mode="before")(_normalize)


class ParticipantOrder(CamelModel):
    participant_ids: list[uuid.UUID] = Field(min_length=1)


class PaymentCreate(CamelModel):
    """Enregistrement d'un paiement de cotisation."""

    amount: Decimal = Field(gt=0)
    method: PaymentMethod = Field(
        default=PaymentMethod.CASH, validation_alias="paymentMethod"
    )
    status: PaymentStatus = PaymentStatus.CONFIRMED
    reference: str | None = Field(default=None, max_length=120)
    comment: str | None = None
    proof_url: str | None = Field(default=None, max_length=512)
    paid_at: datetime | None = None

    # Cible du paiement quand elle n'est pas dans l'URL.
    contribution_id: uuid.UUID | None = None
    cycle_id: uuid.UUID | None = None
    member_id: uuid.UUID | None = None
    tontine_id: uuid.UUID | None = None

    _normalize_enums = field_validator("method", "status", mode="before")(_normalize)

    @model_validator(mode="before")
    @classmethod
    def _accept_both_conventions(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data
        merged = dict(data)
        aliases = {
            "method": "paymentMethod",
            "proof_url": "proofUrl",
            "paid_at": "paidAt",
            "contribution_id": "contributionId",
            "cycle_id": "cycleId",
            "member_id": "memberId",
            "tontine_id": "tontineId",
        }
        for target, source in aliases.items():
            if merged.get(target) is None and merged.get(source) is not None:
                merged[target] = merged[source]
        # `attachmentId` du client : justificatif référencé, stocké tel quel.
        if merged.get("proof_url") is None and merged.get("attachmentId"):
            merged["proof_url"] = merged["attachmentId"]
        return merged


class PaymentClose(CamelModel):
    """Rejet ou annulation d'un paiement."""

    reason: str = Field(min_length=3, max_length=500)
    status: PaymentStatus = PaymentStatus.CANCELLED

    _normalize_status = field_validator("status", mode="before")(_normalize)


class ContributionFilter(CamelModel):
    status: ContributionStatus | None = None
    search: str = ""

    _normalize_status = field_validator("status", mode="before")(_normalize)


class DrawRequest(CamelModel):
    cycle_id: uuid.UUID | None = None
    override: bool = False
    override_reason: str | None = Field(default=None, max_length=500)

    @model_validator(mode="before")
    @classmethod
    def _accept_both_conventions(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data
        merged = dict(data)
        if merged.get("override_reason") is None:
            merged["override_reason"] = merged.get("overrideReason") or merged.get(
                "reason"
            )
        if merged.get("cycle_id") is None and merged.get("cycleId") is not None:
            merged["cycle_id"] = merged["cycleId"]
        return merged


class DrawClose(CamelModel):
    reason: str = Field(min_length=3, max_length=500)


class BeneficiaryDesignate(CamelModel):
    participant_id: uuid.UUID


class PayoutCreate(CamelModel):
    beneficiary_id: uuid.UUID | None = None
    amount: Decimal = Field(gt=0)
    method: PaymentMethod = Field(
        default=PaymentMethod.CASH, validation_alias="paymentMethod"
    )
    status: PayoutStatus = PayoutStatus.PAID
    reference: str | None = Field(default=None, max_length=120)
    comment: str | None = None
    proof_url: str | None = Field(default=None, max_length=512)
    sent_at: datetime | None = None

    _normalize_enums = field_validator("method", "status", mode="before")(_normalize)

    @model_validator(mode="before")
    @classmethod
    def _accept_both_conventions(cls, data: object) -> object:
        if not isinstance(data, dict):
            return data
        merged = dict(data)
        aliases = {
            "beneficiary_id": "beneficiaryId",
            "method": "paymentMethod",
            "proof_url": "proofUrl",
            "sent_at": "sentAt",
        }
        for target, source in aliases.items():
            if merged.get(target) is None and merged.get(source) is not None:
                merged[target] = merged[source]
        if merged.get("proof_url") is None and merged.get("attachmentId"):
            merged["proof_url"] = merged["attachmentId"]
        # Le cahier des charges parle de CONFIRMED ; le contrat client de `paid`.
        if str(merged.get("status", "")).lower() == "confirmed":
            merged["status"] = PayoutStatus.PAID.value
        return merged


class PayoutClose(CamelModel):
    reason: str = Field(min_length=3, max_length=500)
