"""Cibles de relance : qui doit être relancé, et à quel niveau d'urgence.

Les cibles sont **calculées à la demande** depuis les cotisations réelles ;
rien n'est stocké tant qu'une campagne n'est pas envoyée.

Règle importante : un ancien bénéficiaire **fait partie des cibles** — il
continue de cotiser. L'exclure serait la faute classique.

Les campagnes, elles, sont persistées : `send_campaign` enregistre chaque
relance, crée la notification dans l'application et déclenche l'envoi push.

TODO(channels): brancher les passerelles SMS / WhatsApp / e-mail. Ces canaux
sont acceptés mais restent en file (`queued`) plutôt que d'échouer en silence.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from decimal import Decimal

from app.models.contribution import Contribution
from app.models.enums import (
    AuditAction,
    ContributionStatus,
    CycleStatus,
    NotificationType,
    ReminderChannel,
    ReminderLevel,
)
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.reminder import Reminder, ReminderCampaign
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.services.audit_service import AuditService
from app.services.notification_service import NotificationService
from app.services.push_service import PushService
from app.schemas import serializers as out

# Au-delà de ce retard, la relance passe en escalade.
ESCALATION_DAYS = 7

# Écran des cotisations dues, côté application mobile.
MY_DUES_ROUTE = "/my-dues"


class ReminderService:
    def __init__(self, db: Session) -> None:
        self.db = db

    def targets(
        self,
        organization: Organization,
        *,
        tontine_id: uuid.UUID | None = None,
        cycle_id: uuid.UUID | None = None,
    ) -> list[dict[str, Any]]:
        grace_days = int(
            (organization.settings or {}).get("latePaymentGraceDays", 3) or 0
        )
        notify_before = int(
            (organization.settings or {}).get("notifyBeforeDueDays", 3) or 0
        )

        statement = (
            select(Contribution)
            .options(
                joinedload(Contribution.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user)
            )
            .join(TontineCycle, TontineCycle.id == Contribution.cycle_id)
            .join(Tontine, Tontine.id == Contribution.tontine_id)
            .where(
                Contribution.organization_id == organization.id,
                Contribution.status.notin_(
                    [
                        ContributionStatus.PAID.value,
                        ContributionStatus.CANCELLED.value,
                    ]
                ),
                TontineCycle.status.in_(
                    [
                        CycleStatus.UPCOMING.value,
                        CycleStatus.COLLECTING.value,
                        CycleStatus.READY_FOR_DRAW.value,
                    ]
                ),
            )
        )
        if tontine_id is not None:
            statement = statement.where(Contribution.tontine_id == tontine_id)
        if cycle_id is not None:
            statement = statement.where(Contribution.cycle_id == cycle_id)

        now = datetime.now(timezone.utc)
        targets: list[dict[str, Any]] = []

        for contribution in self.db.scalars(statement).unique():
            due = _aware(contribution.due_date)
            days_late = (now - due).days
            if days_late < -notify_before:
                # Trop tôt pour déranger le membre.
                continue

            cycle = self.db.get(TontineCycle, contribution.cycle_id)
            tontine = self.db.get(Tontine, contribution.tontine_id)
            level = _level(days_late, grace_days)

            targets.append(
                {
                    "memberId": str(contribution.participant.organization_member_id),
                    "memberName": contribution.participant.display_name,
                    "participantId": str(contribution.participant_id),
                    "contributionId": str(contribution.id),
                    "tontineId": str(contribution.tontine_id),
                    "tontineName": tontine.name if tontine else "",
                    "cycleId": str(contribution.cycle_id),
                    "periodLabel": cycle.period_label if cycle else "",
                    "periodStart": out.iso(cycle.start_date) if cycle else None,
                    "dueDate": out.iso(contribution.due_date),
                    "amountDue": out.money(contribution.remaining_amount),
                    "level": level.value,
                    "daysLate": max(0, days_late),
                    "reminderCount": 0,
                    "lastReminderAt": None,
                    "hasReceivedPot": contribution.participant.has_received_payout,
                }
            )

        order = {
            ReminderLevel.ESCALATED.value: 0,
            ReminderLevel.LATE.value: 1,
            ReminderLevel.DUE_TODAY.value: 2,
            ReminderLevel.UPCOMING.value: 3,
        }
        targets.sort(key=lambda item: (order[item["level"]], -item["daysLate"]))
        return targets


    # --- Campagnes -----------------------------------------------------------

    def send_campaign(
        self,
        organization: Organization,
        *,
        actor: OrganizationMember,
        tontine_id: uuid.UUID | None,
        cycle_id: uuid.UUID | None,
        channels: list[str],
        messages: dict[uuid.UUID, str],
    ) -> ReminderCampaign:
        """Enregistre une campagne et adresse une relance à chaque membre visé.

        Trois effets, dans cet ordre : la relance est tracée, la notification
        apparaît dans l'application, puis le push part vers les téléphones. Un
        push qui échoue ne remet en cause ni la trace ni la notification —
        l'appareil peut être hors ligne, ce n'est pas une erreur.
        """
        if not channels:
            channels = [ReminderChannel.IN_APP.value]

        members = {
            member.id: member
            for member in self.db.scalars(
                select(OrganizationMember)
                .options(joinedload(OrganizationMember.user))
                .where(OrganizationMember.id.in_(list(messages.keys())))
            ).unique()
        }

        # Le montant dû sert à ordonner les relances et à afficher un total.
        by_member = {
            uuid.UUID(target["memberId"]): target
            for target in self.targets(
                organization, tontine_id=tontine_id, cycle_id=cycle_id
            )
        }

        campaign = ReminderCampaign(
            organization_id=organization.id,
            tontine_id=tontine_id,
            cycle_id=cycle_id,
            channels=",".join(channels),
            created_by=actor.id,
        )
        self.db.add(campaign)
        self.db.flush()

        notifications = NotificationService(self.db)
        total = Decimal("0")
        sent = 0
        recipients: list[uuid.UUID] = []

        for member_id, message in messages.items():
            member = members.get(member_id)
            if member is None:
                # Le membre a pu être retiré entre le calcul et l'envoi.
                continue

            target = by_member.get(member_id, {})
            amount = Decimal(str(target.get("amountDue") or 0))
            total += amount

            for channel in channels:
                # Seul l'in-app est réellement acheminé : les autres canaux
                # restent en file jusqu'à ce qu'une passerelle existe.
                delivered = channel == ReminderChannel.IN_APP.value
                self.db.add(
                    Reminder(
                        organization_id=organization.id,
                        campaign_id=campaign.id,
                        tontine_id=tontine_id,
                        cycle_id=cycle_id,
                        member_id=member.id,
                        member_name=_display_name(member),
                        channel=channel,
                        status="sent" if delivered else "queued",
                        level=str(target.get("level") or ReminderLevel.LATE.value),
                        message=message,
                        amount_due=amount,
                        due_date=None,
                        sent_at=datetime.now(timezone.utc) if delivered else None,
                        sent_by=actor.id,
                    )
                )
                if delivered:
                    sent += 1

            notifications.notify(
                user_id=member.user_id,
                type_=NotificationType.CONTRIBUTION_LATE,
                title=organization.name,
                body=message,
                organization_id=organization.id,
                # La relance n'a d'intérêt que si elle mène à l'écran où le
                # membre voit — et règle — ce qu'il doit.
                target_route=MY_DUES_ROUTE,
            )
            recipients.append(member.user_id)

        campaign.target_count = len(recipients)
        campaign.sent_count = sent
        campaign.total_amount_due = total
        self.db.flush()

        AuditService(self.db).record(
            organization_id=organization.id,
            action=AuditAction.REMINDER_SENT,
            description=f"{len(recipients)} relance(s) envoyée(s).",
            actor=actor,
            target_type="reminder_campaign",
            target_id=campaign.id,
            amount=total,
        )
        self.db.commit()

        # Après le commit : la trace ne doit pas dépendre du réseau.
        PushService(self.db).send_to_users(
            recipients,
            title=organization.name,
            body="Vous avez une cotisation à régler.",
            data={
                "type": NotificationType.CONTRIBUTION_LATE.value,
                # Reprise par le client au moment où l'utilisateur touche la
                # notification : même destination que la version in-app.
                "targetRoute": MY_DUES_ROUTE,
            },
        )
        self.db.commit()
        self.db.refresh(campaign)
        return campaign

    def campaigns(self, organization_id: uuid.UUID) -> list[ReminderCampaign]:
        return list(
            self.db.scalars(
                select(ReminderCampaign)
                .where(ReminderCampaign.organization_id == organization_id)
                .order_by(ReminderCampaign.created_at.desc())
            )
        )

    def reminders_of_campaign(self, campaign_id: uuid.UUID) -> list[Reminder]:
        return list(
            self.db.scalars(
                select(Reminder).where(Reminder.campaign_id == campaign_id)
            )
        )

    def reminders_of_member(
        self, organization_id: uuid.UUID, member_id: uuid.UUID
    ) -> list[Reminder]:
        return list(
            self.db.scalars(
                select(Reminder)
                .where(
                    Reminder.organization_id == organization_id,
                    Reminder.member_id == member_id,
                )
                .order_by(Reminder.created_at.desc())
            )
        )




def _level(days_late: int, grace_days: int) -> ReminderLevel:
    if days_late > grace_days + ESCALATION_DAYS:
        return ReminderLevel.ESCALATED
    if days_late > grace_days:
        return ReminderLevel.LATE
    if days_late >= 0:
        return ReminderLevel.DUE_TODAY
    return ReminderLevel.UPCOMING


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)

def _display_name(member: OrganizationMember) -> str:
    user = member.user
    return f"{user.first_name} {user.last_name}".strip()
