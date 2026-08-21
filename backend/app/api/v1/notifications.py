from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query

from app.core.deps import CurrentUser, DbSession
from app.core.responses import success
from app.schemas.treasury import DeviceRegistration
from app.services.notification_service import NotificationService

router = APIRouter(tags=["notifications"])


@router.get("/notifications", summary="Mes notifications")
def list_notifications(
    db: DbSession,
    user: CurrentUser,
    organization_id: Annotated[
        uuid.UUID | None, Query(alias="organizationId")
    ] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> dict[str, Any]:
    """Toujours celles de l'appelant : `userId` envoyé par le client est ignoré."""
    service = NotificationService(db)
    notifications = service.list_for(
        user.id, organization_id=organization_id, limit=limit
    )
    return success([service.serialize(item) for item in notifications])


@router.get("/notifications/unread-count", summary="Nombre de non lues")
def unread_count(db: DbSession, user: CurrentUser) -> dict[str, Any]:
    return success({"count": NotificationService(db).unread_count(user.id)})


@router.post("/notifications/read-all", summary="Tout marquer comme lu")
def read_all(db: DbSession, user: CurrentUser) -> dict[str, Any]:
    return success({"updated": NotificationService(db).mark_all_read(user.id)})


@router.post("/notifications/{notification_id}/read", summary="Marquer comme lu")
def mark_read(
    db: DbSession, user: CurrentUser, notification_id: uuid.UUID
) -> dict[str, Any]:
    return success(
        {"read": NotificationService(db).mark_read(user.id, notification_id)}
    )


@router.post("/notifications/devices", summary="Enregistrer un appareil")
def register_device(
    db: DbSession, user: CurrentUser, payload: DeviceRegistration
) -> dict[str, Any]:
    """Le jeton est conservé ; l'envoi push reste à brancher (TODO Firebase)."""
    device = NotificationService(db).register_device(
        user.id, payload.token, payload.platform
    )
    return success({"registered": True, "deviceId": str(device.id)})
