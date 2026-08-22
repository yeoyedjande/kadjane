"""Relances : campagnes envoyées et messages individuels.

Une campagne regroupe les relances émises d'un même geste, pour un cycle. La
relance, elle, est nominative : un message, un canal, un état. Rien n'est
supprimé — une relance ratée reste tracée, sans quoi on ne saurait pas
pourquoi un membre n'a rien reçu.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import ReminderLevel


class ReminderCampaign(Base, TimestampMixin):
    """Un envoi groupé de relances, pour un cycle donné."""

    __tablename__ = "reminder_campaigns"
    __table_args__ = (
        Index("ix_reminder_campaigns_org_created", "organization_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="SET NULL"), nullable=True
    )
    cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontine_cycles.id", ondelete="SET NULL"), nullable=True
    )
    # Canaux demandés, séparés par des virgules (`in_app,sms`).
    channels: Mapped[str] = mapped_column(String(120), nullable=False, default="in_app")
    target_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    sent_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_amount_due: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )

    reminders: Mapped[list[Reminder]] = relationship(
        back_populates="campaign", cascade="all, delete-orphan"
    )

    @property
    def channel_list(self) -> list[str]:
        return [c for c in self.channels.split(",") if c]


class Reminder(Base, TimestampMixin):
    """Une relance adressée à un membre."""

    __tablename__ = "reminders"
    __table_args__ = (Index("ix_reminders_member_status", "member_id", "status"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    campaign_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("reminder_campaigns.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="SET NULL"), nullable=True
    )
    cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontine_cycles.id", ondelete="SET NULL"), nullable=True
    )
    # `SET NULL` : retirer un membre ne doit pas effacer la trace des relances.
    member_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    member_name: Mapped[str] = mapped_column(String(240), nullable=False, default="")
    channel: Mapped[str] = mapped_column(String(20), nullable=False, default="in_app")
    # `sent`, `queued` ou `failed` — un canal indisponible reste en file plutôt
    # que d'échouer silencieusement.
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="sent")
    level: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ReminderLevel.LATE.value
    )
    message: Mapped[str] = mapped_column(Text, nullable=False, default="")
    amount_due: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    due_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    sent_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    campaign: Mapped[ReminderCampaign | None] = relationship(
        back_populates="reminders"
    )
