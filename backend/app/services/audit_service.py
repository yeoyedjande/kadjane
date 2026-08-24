"""Journalisation des opérations sensibles.

Toute opération financière ou structurante passe par ici. Les lignes sont
écrites dans la transaction de l'opération : si l'opération échoue, l'audit
n'est pas écrit non plus — et inversement, une opération réussie laisse
toujours sa trace.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.enums import AuditAction
from app.models.membership import OrganizationMember


class AuditService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def record(
        self,
        *,
        organization_id: uuid.UUID,
        action: AuditAction,
        description: str,
        actor: OrganizationMember | None = None,
        target_type: str | None = None,
        target_id: uuid.UUID | None = None,
        tontine_id: uuid.UUID | None = None,
        amount: Decimal | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> AuditLog:
        entry = AuditLog(
            organization_id=organization_id,
            action=action.value,
            description=description,
            actor_member_id=actor.id if actor else None,
            actor_name=actor.user.full_name if actor else "Système",
            target_type=target_type,
            target_id=target_id,
            tontine_id=tontine_id,
            amount=amount,
            audit_metadata=metadata or {},
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(entry)
        self.db.flush()
        return entry

    def history(
        self,
        organization_id: uuid.UUID,
        *,
        tontine_id: uuid.UUID | None = None,
        actions: list[str] | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[AuditLog]:
        return self.paginated_history(
            organization_id,
            tontine_id=tontine_id,
            actions=actions,
            limit=limit,
            offset=offset,
        )[0]

    def paginated_history(
        self,
        organization_id: uuid.UUID,
        *,
        tontine_id: uuid.UUID | None = None,
        actions: list[str] | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[AuditLog], int]:
        """Journal filtré, avec le total avant découpe.

        Le total permet à la console d'afficher « 50 sur 1 240 » plutôt qu'une
        pagination aveugle qui ne sait pas si une page suivante existe.
        """
        statement = select(AuditLog).where(AuditLog.organization_id == organization_id)
        if tontine_id is not None:
            statement = statement.where(AuditLog.tontine_id == tontine_id)
        if actions:
            statement = statement.where(AuditLog.action.in_(actions))

        total = int(
            self.db.scalar(select(func.count()).select_from(statement.subquery())) or 0
        )
        rows = list(
            self.db.scalars(
                statement.order_by(AuditLog.created_at.desc())
                .offset(offset)
                .limit(limit)
            )
        )
        return rows, total
