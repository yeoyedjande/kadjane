"""Notifications in-app.

Le backend crée les notifications au fil des événements métier. Le canal
in-app fonctionne dès maintenant ; l'envoi push consommera les mêmes lignes.

TODO(push): livrer ces notifications via Firebase à partir de `device_tokens`.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.models.enums import NotificationType
from app.models.membership import OrganizationMember
from app.models.notification import DeviceToken, Notification
from app.schemas import serializers as out


class NotificationService:
    def __init__(self, db: Session) -> None:
        self.db = db

    # --- Lecture -------------------------------------------------------------

    def list_for(
        self,
        user_id: uuid.UUID,
        *,
        organization_id: uuid.UUID | None = None,
        limit: int = 50,
    ) -> list[Notification]:
        statement = select(Notification).where(Notification.user_id == user_id)
        if organization_id is not None:
            statement = statement.where(
                Notification.organization_id == organization_id
            )
        statement = statement.order_by(Notification.created_at.desc()).limit(limit)
        return list(self.db.scalars(statement))

    def unread_count(self, user_id: uuid.UUID) -> int:
        return int(
            self.db.scalar(
                select(func.count())
                .select_from(Notification)
                .where(
                    Notification.user_id == user_id,
                    Notification.read_at.is_(None),
                )
            )
            or 0
        )

    # --- Écriture ------------------------------------------------------------

    def notify(
        self,
        *,
        user_id: uuid.UUID,
        type_: NotificationType,
        title: str,
        body: str,
        organization_id: uuid.UUID | None = None,
        target_route: str | None = None,
        data: dict[str, Any] | None = None,
    ) -> Notification:
        notification = Notification(
            user_id=user_id,
            organization_id=organization_id,
            type=type_.value,
            title=title,
            body=body,
            target_route=target_route,
            data=data or {},
        )
        self.db.add(notification)
        self.db.flush()
        return notification

    def notify_members(
        self,
        members: list[OrganizationMember],
        *,
        type_: NotificationType,
        title: str,
        body: str,
        organization_id: uuid.UUID,
        target_route: str | None = None,
        data: dict[str, Any] | None = None,
    ) -> int:
        """Diffuse la même notification à plusieurs membres."""
        for member in members:
            self.notify(
                user_id=member.user_id,
                type_=type_,
                title=title,
                body=body,
                organization_id=organization_id,
                target_route=target_route,
                data=data,
            )
        return len(members)

    def mark_read(self, user_id: uuid.UUID, notification_id: uuid.UUID) -> bool:
        result = self.db.execute(
            update(Notification)
            .where(
                Notification.id == notification_id,
                Notification.user_id == user_id,
                Notification.read_at.is_(None),
            )
            .values(read_at=datetime.now(timezone.utc))
        )
        self.db.commit()
        return bool(result.rowcount)

    def mark_all_read(self, user_id: uuid.UUID) -> int:
        result = self.db.execute(
            update(Notification)
            .where(
                Notification.user_id == user_id,
                Notification.read_at.is_(None),
            )
            .values(read_at=datetime.now(timezone.utc))
        )
        self.db.commit()
        return int(result.rowcount or 0)

    def register_device(
        self, user_id: uuid.UUID, token: str, platform: str = "unknown"
    ) -> DeviceToken:
        existing = self.db.scalars(
            select(DeviceToken).where(DeviceToken.token == token)
        ).first()
        if existing is not None:
            existing.user_id = user_id
            existing.platform = platform
            self.db.commit()
            return existing

        device = DeviceToken(user_id=user_id, token=token, platform=platform)
        self.db.add(device)
        self.db.commit()
        self.db.refresh(device)
        return device

    @staticmethod
    def serialize(notification: Notification) -> dict[str, Any]:
        return {
            "id": str(notification.id),
            "userId": str(notification.user_id),
            "organizationId": str(notification.organization_id)
            if notification.organization_id
            else None,
            "type": notification.type,
            "title": notification.title,
            "body": notification.body,
            "targetRoute": notification.target_route,
            "data": {key: str(value) for key, value in (notification.data or {}).items()},
            "readAt": out.iso(notification.read_at),
            "createdAt": out.iso(notification.created_at),
        }
