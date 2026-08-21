"""Cibles de relance : qui doit être relancé, et à quel niveau d'urgence.

Les cibles sont **calculées à la demande** depuis les cotisations réelles ;
rien n'est stocké tant qu'une campagne n'est pas envoyée.

Règle importante : un ancien bénéficiaire **fait partie des cibles** — il
continue de cotiser. L'exclure serait la faute classique.

TODO(campaigns): persister les campagnes et brancher les canaux SMS /
WhatsApp / e-mail. Le canal in-app fonctionne déjà via les notifications.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.contribution import Contribution
from app.models.enums import ContributionStatus, CycleStatus, ReminderLevel
from app.models.membership import OrganizationMember
from app.models.organization import Organization
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.schemas import serializers as out

# Au-delà de ce retard, la relance passe en escalade.
ESCALATION_DAYS = 7


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
