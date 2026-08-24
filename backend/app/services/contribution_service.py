"""Cotisations et paiements.

Règle financière centrale : **seuls les paiements `confirmed` comptent**.
Les montants stockés (`contribution.paid_amount`, `cycle.collected_amount`)
ne sont jamais incrémentés à la main : ils sont recalculés depuis les
paiements par `recompute_contribution`, ce qui rend impossible toute dérive
entre le stocké et le réel.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.contribution import Contribution, Payment
from app.models.enums import (
    AuditAction,
    ContributionStatus,
    CycleStatus,
    NotificationType,
    PaymentMethod,
    PaymentStatus,
)
from app.models.membership import OrganizationMember
from app.models.tontine import TontineCycle, TontineParticipant
from app.services.audit_service import AuditService
from app.services.notification_service import NotificationService

# Statuts de cycle qu'un mouvement de collecte ne doit jamais écraser.
_SEALED_CYCLE_STATUSES = {
    CycleStatus.DRAWN.value,
    CycleStatus.PAID_OUT.value,
    CycleStatus.CLOSED.value,
}


class ContributionService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)
        self.notifications = NotificationService(db)

    # --- Lecture -------------------------------------------------------------

    def for_cycle(self, cycle_id: uuid.UUID) -> list[Contribution]:
        statement = (
            select(Contribution)
            .options(
                joinedload(Contribution.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user),
                joinedload(Contribution.payments),
            )
            .where(Contribution.cycle_id == cycle_id)
        )
        contributions = list(self.db.scalars(statement).unique())
        contributions.sort(key=lambda c: c.participant.display_name)
        return contributions

    def for_tontine(self, tontine_id: uuid.UUID) -> list[Contribution]:
        statement = (
            select(Contribution)
            .options(
                joinedload(Contribution.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user),
                joinedload(Contribution.payments),
            )
            .where(Contribution.tontine_id == tontine_id)
        )
        return list(self.db.scalars(statement).unique())

    def for_member(
        self, organization_id: uuid.UUID, member_id: uuid.UUID
    ) -> list[Contribution]:
        statement = (
            select(Contribution)
            .options(
                joinedload(Contribution.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user),
                joinedload(Contribution.payments),
            )
            .join(
                TontineParticipant,
                TontineParticipant.id == Contribution.participant_id,
            )
            .where(
                Contribution.organization_id == organization_id,
                TontineParticipant.organization_member_id == member_id,
            )
        )
        return list(self.db.scalars(statement).unique())

    def get(self, contribution_id: uuid.UUID, organization_id: uuid.UUID) -> Contribution:
        contribution = self.db.get(Contribution, contribution_id)
        if contribution is None or contribution.organization_id != organization_id:
            raise NotFoundError("Cotisation introuvable.", code="contribution_not_found")
        return contribution

    def payment(self, payment_id: uuid.UUID, organization_id: uuid.UUID) -> Payment:
        payment = self.db.get(Payment, payment_id)
        if payment is None or payment.organization_id != organization_id:
            raise NotFoundError("Paiement introuvable.", code="payment_not_found")
        return payment

    def find_for_member(
        self, cycle_id: uuid.UUID, member_id: uuid.UUID
    ) -> Contribution:
        """Ligne de cotisation d'un membre pour un cycle."""
        statement = (
            select(Contribution)
            .join(
                TontineParticipant,
                TontineParticipant.id == Contribution.participant_id,
            )
            .where(
                Contribution.cycle_id == cycle_id,
                TontineParticipant.organization_member_id == member_id,
            )
        )
        contribution = self.db.scalars(statement).first()
        if contribution is None:
            raise NotFoundError(
                "Ce membre n'a pas de cotisation attendue sur ce cycle.",
                code="contribution_not_found",
            )
        return contribution

    def missing_for_cycle(self, cycle_id: uuid.UUID) -> tuple[int, Decimal]:
        """`(nombre de cotisations incomplètes, montant restant)`."""
        contributions = self.db.scalars(
            select(Contribution).where(
                Contribution.cycle_id == cycle_id,
                Contribution.status != ContributionStatus.CANCELLED.value,
            )
        ).all()
        remaining = [c for c in contributions if c.paid_amount < c.expected_amount]
        total = sum((c.remaining_amount for c in remaining), Decimal("0"))
        return len(remaining), total

    # --- Écriture ------------------------------------------------------------

    def record_payment(
        self,
        *,
        contribution: Contribution,
        amount: Decimal,
        method: PaymentMethod,
        actor: OrganizationMember,
        status: PaymentStatus = PaymentStatus.CONFIRMED,
        reference: str | None = None,
        comment: str | None = None,
        proof_url: str | None = None,
        paid_at: datetime | None = None,
        commit: bool = True,
    ) -> Payment:
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )
        if status in {PaymentStatus.REJECTED, PaymentStatus.CANCELLED}:
            raise ValidationError(
                "Un paiement ne peut pas être créé annulé ou rejeté.",
                code="invalid_payment_status",
            )

        now = datetime.now(timezone.utc)
        payment = Payment(
            organization_id=contribution.organization_id,
            contribution_id=contribution.id,
            amount=amount,
            payment_method=method.value,
            reference=reference,
            comment=comment,
            proof_url=proof_url,
            status=status.value,
            recorded_by=actor.id,
            paid_at=paid_at or now,
            confirmed_at=now if status is PaymentStatus.CONFIRMED else None,
        )
        self.db.add(payment)
        self.db.flush()

        self.recompute_contribution(contribution)

        member_name = contribution.participant.display_name
        self.audit.record(
            organization_id=contribution.organization_id,
            action=AuditAction.CONTRIBUTION_RECORDED,
            description=f"Paiement de {member_name} enregistré ({method.value}).",
            actor=actor,
            target_type="payment",
            target_id=payment.id,
            tontine_id=contribution.tontine_id,
            amount=amount,
            metadata={
                "cycleId": str(contribution.cycle_id),
                "contributionId": str(contribution.id),
                "status": status.value,
            },
        )
        if status is PaymentStatus.CONFIRMED:
            self.audit.record(
                organization_id=contribution.organization_id,
                action=AuditAction.CONTRIBUTION_CONFIRMED,
                description=f"Cotisation de {member_name} confirmée.",
                actor=actor,
                target_type="payment",
                target_id=payment.id,
                tontine_id=contribution.tontine_id,
                amount=amount,
                metadata={"cycleId": str(contribution.cycle_id)},
            )
            self._notify_paid(contribution, payment)

        if commit:
            self.db.commit()
            self.db.refresh(payment)
        return payment

    def confirm_payment(self, payment: Payment, actor: OrganizationMember) -> Payment:
        if payment.status_enum is PaymentStatus.CONFIRMED:
            return payment
        if payment.status_enum in {PaymentStatus.CANCELLED, PaymentStatus.REJECTED}:
            raise ConflictError(
                "Un paiement annulé ou rejeté ne peut pas être confirmé.",
                code="payment_not_confirmable",
            )

        payment.status = PaymentStatus.CONFIRMED.value
        payment.confirmed_at = datetime.now(timezone.utc)
        self.db.flush()
        self.recompute_contribution(payment.contribution)

        self.audit.record(
            organization_id=payment.organization_id,
            action=AuditAction.CONTRIBUTION_CONFIRMED,
            description=(
                f"Cotisation de {payment.contribution.participant.display_name} confirmée."
            ),
            actor=actor,
            target_type="payment",
            target_id=payment.id,
            tontine_id=payment.contribution.tontine_id,
            amount=payment.amount,
            metadata={"cycleId": str(payment.contribution.cycle_id)},
        )
        self._notify_paid(payment.contribution, payment)
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def close_payment(
        self,
        payment: Payment,
        *,
        status: PaymentStatus,
        reason: str,
        actor: OrganizationMember,
    ) -> Payment:
        """Rejet ou annulation : la ligne reste, elle cesse simplement de compter."""
        if status not in {PaymentStatus.REJECTED, PaymentStatus.CANCELLED}:
            raise ValidationError("Statut de clôture invalide.", code="invalid_status")
        if payment.status_enum is status:
            return payment

        payment.status = status.value
        payment.cancelled_at = datetime.now(timezone.utc)
        payment.cancel_reason = reason
        self.db.flush()
        self.recompute_contribution(payment.contribution)

        self.audit.record(
            organization_id=payment.organization_id,
            action=AuditAction.CONTRIBUTION_CANCELLED,
            description=(
                f"Paiement de {payment.contribution.participant.display_name} "
                f"{'rejeté' if status is PaymentStatus.REJECTED else 'annulé'} : {reason}"
            ),
            actor=actor,
            target_type="payment",
            target_id=payment.id,
            tontine_id=payment.contribution.tontine_id,
            amount=payment.amount,
            metadata={
                "cycleId": str(payment.contribution.cycle_id),
                "status": status.value,
                "reason": reason,
            },
        )
        self.db.commit()
        self.db.refresh(payment)
        return payment

    def _notify_paid(self, contribution: Contribution, payment: Payment) -> None:
        """Prévient le membre que sa cotisation est enregistrée."""
        cycle = self.db.get(TontineCycle, contribution.cycle_id)
        self.notifications.notify(
            user_id=contribution.participant.member.user_id,
            organization_id=contribution.organization_id,
            type_=NotificationType.PAYMENT_CONFIRMED,
            title="Cotisation confirmée",
            body=(
                f"Votre cotisation de {payment.amount:.0f} pour "
                f"{cycle.period_label if cycle else 'la période'} a été enregistrée."
            ),
            target_route=f"/tontine/{contribution.tontine_id}",
            data={"cycleId": str(contribution.cycle_id)},
        )

    # --- Recalcul ------------------------------------------------------------

    def recompute_contribution(self, contribution: Contribution) -> Contribution:
        """Recalcule le payé de la cotisation, puis le collecté du cycle."""
        total = self.db.scalar(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.contribution_id == contribution.id,
                Payment.status == PaymentStatus.CONFIRMED.value,
            )
        )
        contribution.paid_amount = Decimal(str(total or 0))
        contribution.status = self._contribution_status(contribution).value
        self.db.flush()
        self.recompute_cycle(contribution.cycle_id)
        return contribution

    def recompute_cycle(self, cycle_id: uuid.UUID) -> TontineCycle | None:
        cycle = self.db.get(TontineCycle, cycle_id)
        if cycle is None:
            return None

        total = self.db.scalar(
            select(func.coalesce(func.sum(Contribution.paid_amount), 0)).where(
                Contribution.cycle_id == cycle_id
            )
        )
        cycle.collected_amount = Decimal(str(total or 0))

        if cycle.status not in _SEALED_CYCLE_STATUSES:
            complete = cycle.collected_amount >= cycle.expected_amount
            cycle.status = (
                CycleStatus.READY_FOR_DRAW.value
                if complete
                else CycleStatus.COLLECTING.value
            )
        self.db.flush()
        return cycle

    def _contribution_status(self, contribution: Contribution) -> ContributionStatus:
        if contribution.status == ContributionStatus.CANCELLED.value:
            return ContributionStatus.CANCELLED
        if contribution.paid_amount >= contribution.expected_amount:
            return ContributionStatus.PAID
        if contribution.paid_amount > 0:
            return ContributionStatus.PARTIAL
        due = contribution.due_date
        if due.tzinfo is None:
            due = due.replace(tzinfo=timezone.utc)
        if due < datetime.now(timezone.utc):
            return ContributionStatus.LATE
        return ContributionStatus.PENDING
