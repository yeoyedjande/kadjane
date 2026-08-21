"""Agrégats de l'écran d'accueil, calculés depuis la base.

Aucune valeur n'est simulée : ce qui n'existe pas encore vaut zéro et
l'application l'affiche comme tel.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

from app.models.contribution import Contribution
from app.models.enums import ContributionStatus, CycleStatus, TontineStatus
from app.models.organization import Organization
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.repositories.member_repository import MemberRepository
from app.schemas import serializers as out
from app.schemas.organization import OrganizationRead
from app.schemas.base import dump
from app.services.audit_service import AuditService
from app.services.contribution_service import ContributionService
from app.services.draw_service import DrawService
from app.services.payout_service import PayoutService
from app.services.tontine_service import TontineService


class DashboardService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.members = MemberRepository(db)
        self.tontines = TontineService(db)
        self.contributions = ContributionService(db)
        self.payouts = PayoutService(db)
        self.audit = AuditService(db)

    def load(
        self, organization: Organization, member_id: uuid.UUID | None = None
    ) -> dict[str, Any]:
        active_tontines = self.tontines.list_for_organization(
            organization.id, status=TontineStatus.ACTIVE
        )

        expected = Decimal("0")
        collected = Decimal("0")
        late_count = 0
        my_due = Decimal("0")
        my_paid = Decimal("0")
        deadlines: list[dict[str, Any]] = []
        trend: list[dict[str, Any]] = []
        next_draw: dict[str, Any] | None = None
        current_beneficiary: dict[str, Any] | None = None

        for tontine in active_tontines:
            cycle = self.tontines.current_cycle(tontine.id)
            if cycle is None:
                continue

            expected += cycle.expected_amount
            collected += cycle.collected_amount

            lines = self.contributions.for_cycle(cycle.id)
            late_count += sum(
                1
                for line in lines
                if line.status == ContributionStatus.LATE.value
                or (
                    line.paid_amount < line.expected_amount
                    and _aware(line.due_date) < datetime.now(timezone.utc)
                )
            )

            if member_id is not None:
                mine = next(
                    (
                        line
                        for line in lines
                        if line.participant.organization_member_id == member_id
                    ),
                    None,
                )
                if mine is not None:
                    my_due += mine.expected_amount
                    my_paid += mine.paid_amount
                    deadlines.append(
                        {
                            "tontineId": str(tontine.id),
                            "tontineName": tontine.name,
                            "cycleId": str(cycle.id),
                            "periodStart": out.iso(cycle.start_date),
                            "dueDate": out.iso(cycle.due_date),
                            "amount": out.money(mine.expected_amount),
                            "isPaid": mine.status == ContributionStatus.PAID.value,
                        }
                    )

            trend.extend(self._trend_for(tontine))

            if next_draw is None:
                # Le cycle courant peut déjà être tiré : on annonce alors le
                # prochain cycle encore ouvert, pas « aucun tirage ».
                upcoming = self._next_open_cycle(tontine, cycle)
                if upcoming is not None:
                    evaluation = DrawService(self.db).evaluate(tontine, upcoming)
                    next_draw = {
                        "tontineId": str(tontine.id),
                        "tontineName": tontine.name,
                        "cycleId": str(upcoming.id),
                        "periodStart": out.iso(upcoming.start_date),
                        "scheduledAt": out.iso(
                            upcoming.draw_scheduled_at or upcoming.due_date
                        ),
                        "eligibleCount": len(evaluation.eligible),
                        "potAmount": out.money(upcoming.expected_amount),
                        "isUnlocked": evaluation.allowed,
                    }

            if current_beneficiary is None:
                beneficiary = self._latest_beneficiary(tontine)
                if beneficiary is not None:
                    payout = self.payouts.payout_of_cycle(beneficiary.cycle_id)
                    beneficiary_cycle = self.db.get(TontineCycle, beneficiary.cycle_id)
                    current_beneficiary = {
                        "tontineId": str(tontine.id),
                        "tontineName": tontine.name,
                        "cycleId": str(beneficiary.cycle_id),
                        "memberName": beneficiary.participant.display_name,
                        "avatarUrl": beneficiary.participant.member.user.avatar_url,
                        "amount": out.money(beneficiary.expected_payout_amount),
                        "periodStart": out.iso(beneficiary_cycle.start_date)
                        if beneficiary_cycle
                        else None,
                        "isPaidOut": bool(payout and payout.status == "paid"),
                    }

        recent = self.audit.history(organization.id, limit=10)
        remaining = max(Decimal("0"), expected - collected)
        rate = float(collected / expected) if expected > 0 else 0.0

        return {
            "organization": dump(OrganizationRead.model_validate(organization)),
            "membersCount": self.members.count(organization.id),
            "activeTontines": len(active_tontines),
            "expectedThisPeriod": out.money(expected),
            "collectedThisPeriod": out.money(collected),
            "lateContributions": late_count,
            "myContributionDue": out.money(my_due),
            "myContributionPaid": out.money(my_paid),
            "deadlines": deadlines,
            "recentActivity": [out.audit_log(entry) for entry in recent],
            "trend": trend,
            "nextDraw": next_draw,
            "currentBeneficiary": current_beneficiary,
            # Vocabulaire du cahier des charges backend.
            "members_count": self.members.count(organization.id),
            "active_tontines_count": len(active_tontines),
            "expected_this_month": out.money(expected),
            "collected_this_month": out.money(collected),
            "remaining_this_month": out.money(remaining),
            "collection_rate": round(rate, 4),
            "late_contributions_count": late_count,
        }

    # --- Interne -------------------------------------------------------------

    def _trend_for(self, tontine: Tontine) -> list[dict[str, Any]]:
        """Six dernières périodes : attendu contre collecté."""
        cycles = [
            cycle
            for cycle in self.tontines.cycles(tontine.id)
            if _aware(cycle.start_date) <= datetime.now(timezone.utc)
        ]
        return [
            {
                "periodStart": out.iso(cycle.start_date),
                "collected": out.money(cycle.collected_amount),
                "expected": out.money(cycle.expected_amount),
            }
            for cycle in cycles[-6:]
        ]

    def _next_open_cycle(
        self, tontine: Tontine, current: TontineCycle
    ) -> TontineCycle | None:
        """Cycle courant s'il est encore ouvert, sinon le prochain qui l'est."""
        open_statuses = {
            CycleStatus.UPCOMING.value,
            CycleStatus.COLLECTING.value,
            CycleStatus.READY_FOR_DRAW.value,
        }
        if current.status in open_statuses:
            return current
        for cycle in self.tontines.cycles(tontine.id):
            if (
                cycle.sequence_number > current.sequence_number
                and cycle.status in open_statuses
            ):
                return cycle
        return None

    def _latest_beneficiary(self, tontine: Tontine):
        beneficiaries = self.payouts.for_tontine(tontine.id)
        return beneficiaries[-1] if beneficiaries else None


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
