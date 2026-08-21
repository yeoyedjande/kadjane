from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import DrawStatus, DrawType

if TYPE_CHECKING:
    from app.models.tontine import TontineParticipant


class DrawSession(Base, TimestampMixin):
    """Preuve inaltérable d'un tirage.

    Un tirage n'est jamais supprimé : il est annulé (`cancelled`) ou invalidé
    (`invalidated`), et l'audit conserve la trace.

    Le double tirage est empêché **par la base** : l'index unique partiel
    ci-dessous interdit deux sessions `completed` sur un même cycle, quelles
    que soient les requêtes concurrentes.
    """

    __tablename__ = "draw_sessions"
    __table_args__ = (
        Index(
            "uq_draw_sessions_completed_cycle",
            "cycle_id",
            unique=True,
            postgresql_where=text("status = 'completed'"),
            sqlite_where=text("status = 'completed'"),
        ),
        Index("ix_draw_sessions_tontine_created", "tontine_id", "created_at"),
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
    cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tontine_cycles.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    draw_type: Mapped[str] = mapped_column(
        String(24), nullable=False, default=DrawType.PERIODIC.value
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=DrawStatus.COMPLETED.value
    )
    period_label: Mapped[str] = mapped_column(String(60), nullable=False, default="")
    winner_participant_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("tontine_participants.id", ondelete="SET NULL"),
        nullable=True,
    )
    drawn_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    override_used: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    override_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_reference: Mapped[str] = mapped_column(String(40), nullable=False)
    random_source: Mapped[str] = mapped_column(
        String(40), nullable=False, default="server_secrets_choice"
    )
    seed: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    scheduled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    close_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    entries: Mapped[list[DrawParticipant]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="DrawParticipant.position",
    )
    winner: Mapped[TontineParticipant | None] = relationship(
        foreign_keys=[winner_participant_id]
    )

    @property
    def status_enum(self) -> DrawStatus:
        return DrawStatus(self.status)


class DrawParticipant(Base):
    """Liste exacte des participants présents au moment du tirage.

    Elle est figée : la roue affichée par l'application s'aligne dessus, et
    l'historique reste vérifiable même si l'éligibilité change ensuite.
    """

    __tablename__ = "draw_participants"
    __table_args__ = (
        UniqueConstraint(
            "draw_session_id", "participant_id", name="uq_draw_participants_unique"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    draw_session_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("draw_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    participant_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("tontine_participants.id", ondelete="CASCADE"),
        nullable=False,
    )
    display_name: Mapped[str] = mapped_column(String(240), nullable=False)
    was_eligible: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    position: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    weight: Mapped[int] = mapped_column(Integer, nullable=False, default=1)

    session: Mapped[DrawSession] = relationship(back_populates="entries")
    participant: Mapped[TontineParticipant] = relationship()
