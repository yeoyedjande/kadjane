from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, Index, Numeric, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, new_uuid


class AuditLog(Base):
    """Journal des opérations sensibles.

    Écriture seule : une ligne d'audit n'est ni modifiée ni supprimée.
    """

    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_org_created", "organization_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    action: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    actor_member_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    actor_name: Mapped[str] = mapped_column(
        String(240), nullable=False, default="Système"
    )
    target_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    target_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True)
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="CASCADE"), nullable=True, index=True
    )
    amount: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), nullable=True)
    audit_metadata: Mapped[dict[str, Any]] = mapped_column(
        "metadata", JSON, nullable=False, default=dict
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
