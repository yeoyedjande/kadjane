from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import (
    AllocationMode,
    CycleStatus,
    TontineFrequency,
    TontineStatus,
)

if TYPE_CHECKING:
    from app.models.membership import OrganizationMember


class Tontine(Base, TimestampMixin):
    __tablename__ = "tontines"
    __table_args__ = (
        UniqueConstraint("organization_id", "name", name="uq_tontines_org_name"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    contribution_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False
    )
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="XOF")
    frequency: Mapped[str] = mapped_column(
        String(20), nullable=False, default=TontineFrequency.MONTHLY.value
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    due_day: Mapped[int] = mapped_column(Integer, nullable=False, default=5)
    custom_period_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    attribution_mode: Mapped[str] = mapped_column(
        String(32), nullable=False, default=AllocationMode.MONTHLY_DRAW.value
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=TontineStatus.DRAFT.value, index=True
    )

    # Règles du tirage, réglables par tontine.
    require_all_contributions_before_draw: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    allow_draw_override: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    activated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    participants: Mapped[list[TontineParticipant]] = relationship(
        back_populates="tontine",
        cascade="all, delete-orphan",
        order_by="TontineParticipant.joined_at",
    )
    cycles: Mapped[list[TontineCycle]] = relationship(
        back_populates="tontine",
        cascade="all, delete-orphan",
        order_by="TontineCycle.sequence_number",
    )

    @property
    def status_enum(self) -> TontineStatus:
        return TontineStatus(self.status)

    @property
    def mode(self) -> AllocationMode:
        return AllocationMode(self.attribution_mode)

    @property
    def frequency_enum(self) -> TontineFrequency:
        return TontineFrequency(self.frequency)

    def pot_for(self, participant_count: int) -> Decimal:
        """Cagnotte théorique : jamais une constante, toujours un calcul."""
        return self.contribution_amount * participant_count


class TontineParticipant(Base, TimestampMixin):
    """Participation d'un membre à une tontine.

    Distinction fondamentale de Kadjane :

    * `is_active` reste `True` après réception de la cagnotte — le membre
      continue de cotiser jusqu'à la fin ;
    * seul `is_draw_eligible` bascule à `False` : il sort de la roue, pas de
      la tontine.
    """

    __tablename__ = "tontine_participants"
    __table_args__ = (
        UniqueConstraint(
            "tontine_id",
            "organization_member_id",
            name="uq_tontine_participants_tontine_member",
        ),
        UniqueConstraint(
            "tontine_id", "draw_position", name="uq_tontine_participants_position"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    tontine_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="CASCADE"), nullable=False, index=True
    )
    organization_member_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organization_members.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_draw_eligible: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    has_received_payout: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    draw_position: Mapped[int | None] = mapped_column(Integer, nullable=True)
    received_cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontine_cycles.id", ondelete="SET NULL"), nullable=True
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    tontine: Mapped[Tontine] = relationship(back_populates="participants")
    member: Mapped[OrganizationMember] = relationship(
        foreign_keys=[organization_member_id]
    )

    @property
    def display_name(self) -> str:
        user = self.member.user
        return f"{user.first_name} {user.last_name}".strip()


class TontineCycle(Base, TimestampMixin):
    """Une période de collecte : « Août 2026 »."""

    __tablename__ = "tontine_cycles"
    __table_args__ = (
        UniqueConstraint(
            "tontine_id", "sequence_number", name="uq_tontine_cycles_sequence"
        ),
        Index("ix_tontine_cycles_tontine_status", "tontine_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    tontine_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="CASCADE"), nullable=False, index=True
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)
    period_label: Mapped[str] = mapped_column(String(60), nullable=False)
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    due_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expected_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    collected_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=CycleStatus.UPCOMING.value
    )
    draw_scheduled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    tontine: Mapped[Tontine] = relationship(back_populates="cycles")

    @property
    def status_enum(self) -> CycleStatus:
        return CycleStatus(self.status)
