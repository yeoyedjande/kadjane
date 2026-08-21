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
    text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import BeneficiaryStatus, DrawType, PayoutStatus

if TYPE_CHECKING:
    from app.models.tontine import TontineParticipant


class Beneficiary(Base, TimestampMixin):
    """Participant désigné pour recevoir la cagnotte d'un cycle.

    Un cycle ne peut avoir qu'un bénéficiaire vivant : l'index unique partiel
    l'impose en base, indépendamment du code applicatif.
    """

    __tablename__ = "beneficiaries"
    __table_args__ = (
        Index(
            "uq_beneficiaries_active_cycle",
            "cycle_id",
            unique=True,
            postgresql_where=text("status <> 'cancelled'"),
            sqlite_where=text("status <> 'cancelled'"),
        ),
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
    )
    draw_session_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("draw_sessions.id", ondelete="SET NULL"), nullable=True
    )
    expected_payout_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False
    )
    source: Mapped[str] = mapped_column(
        String(24), nullable=False, default=DrawType.PERIODIC.value
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=BeneficiaryStatus.DESIGNATED.value
    )
    designated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    cancel_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    participant: Mapped[TontineParticipant] = relationship()
    payouts: Mapped[list[Payout]] = relationship(
        back_populates="beneficiary",
        cascade="all, delete-orphan",
        order_by="Payout.created_at",
    )

    @property
    def status_enum(self) -> BeneficiaryStatus:
        return BeneficiaryStatus(self.status)


class Payout(Base, TimestampMixin):
    """Versement de la cagnotte au bénéficiaire.

    Aucune suppression : une opération annulée passe en `failed` avec sa
    raison, et l'audit conserve la trace.
    """

    __tablename__ = "payouts"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    beneficiary_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("beneficiaries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(24), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=PayoutStatus.PENDING.value
    )
    paid_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    beneficiary: Mapped[Beneficiary] = relationship(back_populates="payouts")

    @property
    def status_enum(self) -> PayoutStatus:
        return PayoutStatus(self.status)
