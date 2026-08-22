from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession, OrgContext, TontineCtx
from app.core.errors import NotFoundError
from app.repositories.member_repository import MemberRepository
from app.schemas import serializers as out
from app.schemas.reminder import ReminderCampaignCreate
from app.services.organization_service import OrganizationService
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
    summary="Campagnes de relance",
)
def list_reminder_campaigns(db: DbSession, context: OrgContext) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "reminder.view")
    service = ReminderService(db)
    return success(
        [
            _campaign_payload(campaign)
            for campaign in service.campaigns(context.organization_id)
        ]
    )


@router.post(
    "/reminder-campaigns",
    status_code=status.HTTP_201_CREATED,
    summary="Envoyer une campagne de relance",
)
def send_reminder_campaign(
    db: DbSession, user: CurrentUser, payload: ReminderCampaignCreate
) -> dict[str, Any]:
    """Relance les membres visés : trace, notification, puis push.

    Le trésorier peut le faire depuis l'application mobile comme depuis le
    back-office.
    """
    membership = MemberRepository(db).by_id(payload.actor_member_id)
    # Adhésion inconnue, ou appartenant à quelqu'un d'autre : on ne relance pas
    # au nom d'un tiers. 404 plutôt que 403, pour ne rien révéler.
    if membership is None or membership.user_id != user.id:
        raise NotFoundError("Adhésion introuvable.", code="member_not_found")
    permission_service.require(membership.role_enum, "reminder.send")

    organization = OrganizationService(db).get(membership.organization_id)
    service = ReminderService(db)
    campaign = service.send_campaign(
        organization,
        actor=membership,
        tontine_id=payload.tontine_id,
        cycle_id=payload.cycle_id,
        channels=[channel.value for channel in payload.channels],
        messages={uuid.UUID(k): v for k, v in payload.messages.items()},
    )
    return success(
        {
            "campaign": _campaign_payload(campaign),
            "reminders": [
                _reminder_payload(reminder)
                for reminder in service.reminders_of_campaign(campaign.id)
            ],
        }
    )


@router.get(
    "/organizations/{organization_id}/members/{member_id}/reminders",
    summary="Relances d'un membre",
)
def list_member_reminders(
    db: DbSession, context: OrgContext, member_id: uuid.UUID
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "reminder.view")
    return success(
        [
            _reminder_payload(reminder)
            for reminder in ReminderService(db).reminders_of_member(
                context.organization_id, member_id
            )
        ]
    )


# --- Sérialisation ----------------------------------------------------------


def _campaign_payload(campaign) -> dict[str, Any]:
    return {
        "id": str(campaign.id),
        "organizationId": str(campaign.organization_id),
        "tontineId": str(campaign.tontine_id) if campaign.tontine_id else "",
        "tontineName": "",
        "cycleId": str(campaign.cycle_id) if campaign.cycle_id else "",
        "periodLabel": "",
        "channels": campaign.channel_list,
        "targetCount": campaign.target_count,
        "sentCount": campaign.sent_count,
        "totalAmountDue": out.money(campaign.total_amount_due),
        "createdAt": out.iso(campaign.created_at),
        "createdByMemberId": str(campaign.created_by) if campaign.created_by else None,
        "createdByName": None,
    }


def _reminder_payload(reminder) -> dict[str, Any]:
    return {
        "id": str(reminder.id),
        "organizationId": str(reminder.organization_id),
        "campaignId": str(reminder.campaign_id) if reminder.campaign_id else None,
        "tontineId": str(reminder.tontine_id) if reminder.tontine_id else "",
        "cycleId": str(reminder.cycle_id) if reminder.cycle_id else "",
        "memberId": str(reminder.member_id) if reminder.member_id else "",
        "memberName": reminder.member_name,
        "channel": reminder.channel,
        "status": reminder.status,
        "level": reminder.level,
        "message": reminder.message,
        "amountDue": out.money(reminder.amount_due),
        "dueDate": out.iso(reminder.due_date) if reminder.due_date else None,
        "createdAt": out.iso(reminder.created_at),
        "sentAt": out.iso(reminder.sent_at) if reminder.sent_at else None,
        "readAt": out.iso(reminder.read_at) if reminder.read_at else None,
        "sentByMemberId": str(reminder.sent_by) if reminder.sent_by else None,
        "failureReason": reminder.failure_reason,
    }
