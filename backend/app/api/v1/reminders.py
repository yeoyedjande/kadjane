from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query

from app.core.deps import DbSession, OrgContext, TontineCtx
from app.core.responses import success
from app.services import permission_service
from app.services.reminder_service import ReminderService
from app.services.tontine_service import TontineService

router = APIRouter(tags=["relances"])


@router.get(
    "/organizations/{organization_id}/reminder-targets", summary="Membres à relancer"
)
def list_reminder_targets(
    db: DbSession,
    context: OrgContext,
    tontine_id: Annotated[uuid.UUID | None, Query(alias="tontineId")] = None,
) -> dict[str, Any]:
    """Cotisations non réglées, classées par urgence.

    Un ancien bénéficiaire y figure : il continue de cotiser.
    """
    permission_service.require(context.membership.role_enum, "reminder.view")
    targets = ReminderService(db).targets(context.organization, tontine_id=tontine_id)
    return success(targets, meta={"total": len(targets)})


@router.get(
    "/tontines/{tontine_id}/cycles/{cycle_id}/reminder-targets",
    summary="Membres à relancer sur un cycle",
)
def list_cycle_reminder_targets(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "reminder.view")
    TontineService(db).cycle(cycle_id, context.organization_id)
    targets = ReminderService(db).targets(
        context.organization, tontine_id=context.tontine.id, cycle_id=cycle_id
    )
    return success(targets, meta={"total": len(targets)})


@router.get(
    "/organizations/{organization_id}/reminder-campaigns",
    summary="Campagnes de relance (à venir)",
)
def list_reminder_campaigns(context: OrgContext) -> dict[str, Any]:
    # TODO(campaigns): persister les campagnes et brancher SMS / WhatsApp.
    return success([])


@router.get(
    "/organizations/{organization_id}/members/{member_id}/reminders",
    summary="Relances d'un membre (à venir)",
)
def list_member_reminders(context: OrgContext, member_id: uuid.UUID) -> dict[str, Any]:
    # TODO(campaigns): historique des relances envoyées.
    return success([])
