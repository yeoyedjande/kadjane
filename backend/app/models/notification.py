from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import JSON, DateTime, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import NotificationType


class Notification(Base, TimestampMixin):
    """Notification destinée à un utilisateur.

    Elle est créée par le backend au fil des événements métier (paiement
    confirmé, tirage, versement…). L'envoi push reste à brancher : le canal
    « in-app » fonctionne déjà, c'est cette table qui l'alimente.
    """

    __tablename__ = "notifications"
    __table_args__ = (
        Index("ix_notifications_user_read", "user_id", "read_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=True, index=True
    )
    type: Mapped[str] = mapped_column(
        String(32), nullable=False, default=NotificationType.ANNOUNCEMENT.value
    )
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False, default="")
    target_route: Mapped[str | None] = mapped_column(String(255), nullable=True)
    data: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class DeviceToken(Base, TimestampMixin):
    """Appareil enregistré pour les notifications push.

    TODO(push): consommer ces jetons depuis un service Firebase.
    """

    __tablename__ = "device_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False, unique=True)
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="unknown")
