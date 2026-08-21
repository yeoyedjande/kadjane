from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import ContributionStatus, PaymentStatus

if TYPE_CHECKING:
    from app.models.tontine import TontineParticipant


class Contribution(Base, TimestampMixin):
    """Ce qu'un participant **doit** pour un cycle.

    Une ligne par participant actif et par cycle — y compris pour un membre
    ayant déjà reçu la cagnotte : il continue de cotiser.

    `paid_amount` est un cumul dérivé des paiements `confirmed` uniquement,
    recalculé par `ContributionService` : il ne se met jamais à jour tout seul.
    """

    __tablename__ = "contributions"
    __table_args__ = (
        UniqueConstraint(
            "cycle_id", "participant_id", name="uq_contributions_cycle_participant"
        ),
        Index("ix_contributions_cycle_status", "cycle_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tontine_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="CASCADE"), nullable=False, index=True
    )
    cycle_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("tontine_cycles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    participant_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("tontine_participants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    expected_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    paid_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ContributionStatus.PENDING.value
    )
    due_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    participant: Mapped[TontineParticipant] = relationship()
    payments: Mapped[list[Payment]] = relationship(
        back_populates="contribution",
        cascade="all, delete-orphan",
        order_by="Payment.created_at",
    )

    @property
    def status_enum(self) -> ContributionStatus:
        return ContributionStatus(self.status)

    @property
    def remaining_amount(self) -> Decimal:
        return max(Decimal("0"), self.expected_amount - self.paid_amount)

    @property
    def is_settled(self) -> bool:
        return self.status in {
            ContributionStatus.PAID.value,
            ContributionStatus.CANCELLED.value,
        }


class Payment(Base, TimestampMixin):
    """Un versement enregistré pour une cotisation.

    Seul un paiement `confirmed` alimente `contribution.paid_amount` et
    `cycle.collected_amount`. Un paiement annulé ou rejeté reste dans
    l'historique : aucune écriture financière n'est supprimée.
    """

    __tablename__ = "payments"
    __table_args__ = (
        Index("ix_payments_contribution_status", "contribution_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    contribution_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("contributions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(24), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=PaymentStatus.PENDING.value
    )
    recorded_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancel_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    contribution: Mapped[Contribution] = relationship(back_populates="payments")

    @property
    def status_enum(self) -> PaymentStatus:
        return PaymentStatus(self.status)
