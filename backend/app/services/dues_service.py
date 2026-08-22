"""Cotisations de caisse : plans, échéances et règlements.

Les échéances sont engendrées **paresseusement**, à la lecture : aucune tâche
planifiée n'est nécessaire, et une organisation inactive pendant six mois
retrouve ses six échéances au premier accès.

Deux règles d'équité gouvernent cette génération :

* seuls les membres **actifs** reçoivent de nouvelles échéances ;
* un membre ne doit rien pour les périodes **antérieures à son adhésion**.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.dues import DuesEntry, DuesPayment, DuesPlan
from app.models.enums import (
    AuditAction,
    ContributionStatus,
    DuesPlanStatus,
    MemberStatus,
    PaymentMethod,
    PaymentStatus,
    TontineFrequency,
)
from app.models.membership import OrganizationMember
from app.services.audit_service import AuditService
from app.services.period_service import build_periods

# Au-delà, on cesse d'engendrer : un plan démarré par erreur en 1990 ne doit
# pas remplir la base de milliers d'échéances.
MAX_PERIODS = 240


class DuesService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)

    # --- Plans ---------------------------------------------------------------

    def create_plan(
        self,
        organization_id: uuid.UUID,
        *,
        name: str,
        amount: Decimal,
        actor: OrganizationMember,
        frequency: TontineFrequency = TontineFrequency.MONTHLY,
        due_day: int = 5,
        custom_period_days: int | None = None,
        start_date: date | None = None,
        description: str | None = None,
        currency: str = "XOF",
    ) -> DuesPlan:
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )

        existing = self.db.scalars(
            select(DuesPlan).where(
                DuesPlan.organization_id == organization_id,
                func.lower(DuesPlan.name) == name.strip().lower(),
            )
        ).first()
        if existing is not None:
            raise ConflictError(
                "Une cotisation porte déjà ce nom.", code="dues_plan_exists"
            )

        plan = DuesPlan(
            organization_id=organization_id,
            name=name.strip(),
            description=description,
            amount=amount,
            currency=currency,
            frequency=frequency.value,
            due_day=due_day,
            custom_period_days=custom_period_days,
            start_date=start_date or date.today().replace(day=1),
            created_by=actor.id,
        )
        self.db.add(plan)
        self.db.flush()

        self.audit.record(
            organization_id=organization_id,
            action=AuditAction.DUES_PLAN_CREATED,
            description=f"Cotisation « {plan.name} » créée ({amount} {currency}).",
            actor=actor,
            target_type="dues_plan",
            target_id=plan.id,
            amount=amount,
        )
        self.db.commit()
        self.db.refresh(plan)
        return plan

    def plans(self, organization_id: uuid.UUID) -> list[DuesPlan]:
        return list(
            self.db.scalars(
                select(DuesPlan)
                .where(DuesPlan.organization_id == organization_id)
                .order_by(DuesPlan.created_at)
            )
        )

    def get_plan(self, plan_id: uuid.UUID, organization_id: uuid.UUID) -> DuesPlan:
        """Charge un plan **et** vérifie qu'il appartient à l'organisation.

        Point de contrôle de l'isolation multi-association : un identifiant
        appartenant à une autre organisation est traité comme inexistant.
        """
        plan = self.db.get(DuesPlan, plan_id)
        if plan is None or plan.organization_id != organization_id:
            raise NotFoundError("Cotisation introuvable.", code="dues_plan_not_found")
        return plan

    def update_plan(
        self,
        plan: DuesPlan,
        actor: OrganizationMember,
        *,
        name: str | None = None,
        amount: Decimal | None = None,
        description: str | None = None,
        due_day: int | None = None,
        status: DuesPlanStatus | None = None,
    ) -> DuesPlan:
        """Met à jour un plan.

        Un changement de montant ne touche **pas** les échéances déjà
        engendrées : réécrire le passé fausserait les comptes du trésorier.
        Il ne vaut que pour les périodes à venir.
        """
        if amount is not None:
            if amount <= 0:
                raise ValidationError(
                    "Le montant doit être supérieur à zéro.", code="invalid_amount"
                )
            plan.amount = amount
        if name is not None:
            plan.name = name.strip()
        if description is not None:
            plan.description = description
        if due_day is not None:
            plan.due_day = due_day
        if status is not None:
            plan.status = status.value

        self.audit.record(
            organization_id=plan.organization_id,
            action=AuditAction.DUES_PLAN_UPDATED,
            description=f"Cotisation « {plan.name} » modifiée.",
            actor=actor,
            target_type="dues_plan",
            target_id=plan.id,
        )
        self.db.commit()
        self.db.refresh(plan)
        return plan

    # --- Échéances -----------------------------------------------------------

    def ensure_entries(self, plan: DuesPlan, *, today: date | None = None) -> int:
        """Engendre les échéances manquantes jusqu'à la période en cours.

        Idempotent : une contrainte d'unicité sur (plan, membre, période) rend
        un appel répété sans effet. Retourne le nombre de lignes créées.
        """
        if not plan.is_open:
            return 0

        reference = today or date.today()
        if reference < plan.start_date:
            return 0

        periods = build_periods(
            start_date=plan.start_date,
            frequency=plan.frequency_enum,
            count=self._elapsed_periods(plan, reference),
            due_day=plan.due_day,
            custom_period_days=plan.custom_period_days,
        )
        if not periods:
            return 0

        members = list(
            self.db.scalars(
                select(OrganizationMember).where(
                    OrganizationMember.organization_id == plan.organization_id,
                    OrganizationMember.status == MemberStatus.ACTIVE.value,
                )
            )
        )

        known = {
            (entry.member_id, entry.sequence_number)
            for entry in self.db.scalars(
                select(DuesEntry).where(DuesEntry.plan_id == plan.id)
            )
        }

        created = 0
        for period in periods:
            for member in members:
                if (member.id, period.sequence_number) in known:
                    continue
                # Rien n'est dû pour une période close avant l'adhésion.
                if _aware(member.joined_at) > period.end:
                    continue
                self.db.add(
                    DuesEntry(
                        organization_id=plan.organization_id,
                        plan_id=plan.id,
                        member_id=member.id,
                        sequence_number=period.sequence_number,
                        period_label=period.label,
                        period_start=period.start,
                        period_end=period.end,
                        due_date=period.due,
                        expected_amount=plan.amount,
                    )
                )
                created += 1

        if created:
            self.db.flush()
        self._refresh_late_status(plan.id)
        self.db.commit()
        return created

    def entries(
        self,
        plan: DuesPlan,
        *,
        sequence_number: int | None = None,
        member_id: uuid.UUID | None = None,
    ) -> list[DuesEntry]:
        statement = (
            select(DuesEntry)
            .options(joinedload(DuesEntry.member).joinedload(OrganizationMember.user))
            .where(DuesEntry.plan_id == plan.id)
        )
        if sequence_number is not None:
            statement = statement.where(DuesEntry.sequence_number == sequence_number)
        if member_id is not None:
            statement = statement.where(DuesEntry.member_id == member_id)
        statement = statement.order_by(
            DuesEntry.sequence_number.desc(), DuesEntry.created_at
        )
        return list(self.db.scalars(statement).unique())

    def get_entry(self, entry_id: uuid.UUID, organization_id: uuid.UUID) -> DuesEntry:
        entry = self.db.get(DuesEntry, entry_id)
        if entry is None or entry.organization_id != organization_id:
            raise NotFoundError("Échéance introuvable.", code="dues_entry_not_found")
        return entry

    def outstanding(
        self, organization_id: uuid.UUID, *, member_id: uuid.UUID | None = None
    ) -> list[DuesEntry]:
        """Échéances non soldées, les plus anciennes d'abord.

        Alimente le centre de relance : c'est ce que le trésorier réclame.
        """
        statement = (
            select(DuesEntry)
            .options(
                joinedload(DuesEntry.member).joinedload(OrganizationMember.user),
                joinedload(DuesEntry.plan),
            )
            .where(
                DuesEntry.organization_id == organization_id,
                DuesEntry.status.notin_(
                    [
                        ContributionStatus.PAID.value,
                        ContributionStatus.CANCELLED.value,
                    ]
                ),
            )
        )
        if member_id is not None:
            statement = statement.where(DuesEntry.member_id == member_id)
        return list(
            self.db.scalars(statement.order_by(DuesEntry.due_date)).unique()
        )

    # --- Règlements ----------------------------------------------------------

    def record_payment(
        self,
        *,
        entry: DuesEntry,
        amount: Decimal,
        method: PaymentMethod,
        actor: OrganizationMember,
        reference: str | None = None,
        comment: str | None = None,
        proof_url: str | None = None,
        paid_at: datetime | None = None,
    ) -> DuesPayment:
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )
        if entry.status == ContributionStatus.CANCELLED.value:
            raise ConflictError(
                "Cette échéance a été annulée.", code="dues_entry_cancelled"
            )

        now = datetime.now(timezone.utc)
        payment = DuesPayment(
            organization_id=entry.organization_id,
            entry_id=entry.id,
            amount=amount,
            payment_method=method.value,
            reference=reference,
            comment=comment,
            proof_url=proof_url,
            status=PaymentStatus.CONFIRMED.value,
            recorded_by=actor.id,
            paid_at=paid_at or now,
        )
        self.db.add(payment)
        self.db.flush()
        self.recompute_entry(entry)

        self.audit.record(
            organization_id=entry.organization_id,
            action=AuditAction.DUES_PAYMENT_RECORDED,
            description=(
                f"Cotisation « {entry.plan.name} » — {entry.period_label} : "
                f"{amount} encaissé."
            ),
            actor=actor,
            target_type="dues_entry",
            target_id=entry.id,
            amount=amount,
        )
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def cancel_payment(
        self, payment: DuesPayment, actor: OrganizationMember, *, reason: str
    ) -> DuesPayment:
        """Annule un règlement sans le supprimer : l'historique reste complet."""
        if payment.status == PaymentStatus.CANCELLED.value:
            raise ConflictError(
                "Ce règlement est déjà annulé.", code="payment_already_cancelled"
            )

        payment.status = PaymentStatus.CANCELLED.value
        payment.cancelled_at = datetime.now(timezone.utc)
        payment.cancel_reason = reason
        self.db.flush()
        self.recompute_entry(payment.entry)

        self.audit.record(
            organization_id=payment.organization_id,
            action=AuditAction.DUES_PAYMENT_CANCELLED,
            description=f"Règlement de cotisation annulé : {reason}",
            actor=actor,
            target_type="dues_entry",
            target_id=payment.entry_id,
            amount=payment.amount,
        )
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def recompute_entry(self, entry: DuesEntry) -> DuesEntry:
        """Recalcule le payé de l'échéance depuis ses règlements confirmés."""
        total = self.db.scalar(
            select(func.coalesce(func.sum(DuesPayment.amount), 0)).where(
                DuesPayment.entry_id == entry.id,
                DuesPayment.status == PaymentStatus.CONFIRMED.value,
            )
        )
        entry.paid_amount = Decimal(str(total or 0))
        entry.status = self._entry_status(entry).value
        self.db.flush()
        return entry

    # --- Synthèses -----------------------------------------------------------

    def collected_total(self, organization_id: uuid.UUID) -> Decimal:
        """Somme encaissée pour l'ensemble des cotisations de caisse.

        La trésorerie en a besoin : sans cela, l'argent de la caisse
        n'apparaîtrait nulle part dans le solde.
        """
        total = self.db.scalar(
            select(func.coalesce(func.sum(DuesPayment.amount), 0)).where(
                DuesPayment.organization_id == organization_id,
                DuesPayment.status == PaymentStatus.CONFIRMED.value,
            )
        )
        return Decimal(str(total or 0))

    def plan_summary(self, plan: DuesPlan) -> dict[str, object]:
        entries = self.entries(plan)
        expected = sum((e.expected_amount for e in entries), Decimal("0"))
        collected = sum((e.paid_amount for e in entries), Decimal("0"))
        unpaid = [e for e in entries if not e.is_settled]
        current = max((e.sequence_number for e in entries), default=0)
        return {
            "expectedTotal": expected,
            "collectedTotal": collected,
            "outstandingTotal": max(Decimal("0"), expected - collected),
            "unpaidCount": len(unpaid),
            "memberCount": len({e.member_id for e in entries}),
            "currentPeriod": current,
        }

    # --- Interne -------------------------------------------------------------

    def _elapsed_periods(self, plan: DuesPlan, reference: date) -> int:
        """Nombre de périodes commencées, la période en cours comprise."""
        probe = build_periods(
            start_date=plan.start_date,
            frequency=plan.frequency_enum,
            count=MAX_PERIODS,
            due_day=plan.due_day,
            custom_period_days=plan.custom_period_days,
        )
        started = [p for p in probe if p.start.date() <= reference]
        return len(started)

    def _refresh_late_status(self, plan_id: uuid.UUID) -> None:
        """Bascule en retard les échéances impayées dont la date est passée."""
        now = datetime.now(timezone.utc)
        for entry in self.db.scalars(
            select(DuesEntry).where(
                DuesEntry.plan_id == plan_id,
                DuesEntry.status.in_(
                    [
                        ContributionStatus.PENDING.value,
                        ContributionStatus.PARTIAL.value,
                    ]
                ),
            )
        ):
            if _aware(entry.due_date) < now:
                entry.status = ContributionStatus.LATE.value

    @staticmethod
    def _entry_status(entry: DuesEntry) -> ContributionStatus:
        if entry.paid_amount >= entry.expected_amount:
            return ContributionStatus.PAID
        now = datetime.now(timezone.utc)
        if entry.paid_amount > 0:
            return ContributionStatus.PARTIAL
        if _aware(entry.due_date) < now:
            return ContributionStatus.LATE
        return ContributionStatus.PENDING


def _aware(value: datetime) -> datetime:
    """SQLite restitue des datetimes naïfs ; on les ramène en UTC."""
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
