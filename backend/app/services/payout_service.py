"""Bénéficiaires et versement de la cagnotte."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.enums import (
    AuditAction,
    BeneficiaryStatus,
    CycleStatus,
    DrawType,
    NotificationType,
    PaymentMethod,
    PayoutStatus,
    TontineStatus,
)
from app.models.membership import OrganizationMember
from app.models.payout import Beneficiary, Payout
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.services.audit_service import AuditService
from app.services.notification_service import NotificationService

_LOAD_PARTICIPANT = (
    joinedload(Beneficiary.participant)
    .joinedload(TontineParticipant.member)
    .joinedload(OrganizationMember.user)
)


class PayoutService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)
        self.notifications = NotificationService(db)

    # --- Bénéficiaires -------------------------------------------------------

    def for_tontine(self, tontine_id: uuid.UUID) -> list[Beneficiary]:
        statement = (
            select(Beneficiary)
            .options(_LOAD_PARTICIPANT, joinedload(Beneficiary.payouts))
            .where(Beneficiary.tontine_id == tontine_id)
            .order_by(Beneficiary.designated_at)
        )
        return list(self.db.scalars(statement).unique())

    def of_cycle(self, cycle_id: uuid.UUID) -> Beneficiary | None:
        statement = (
            select(Beneficiary)
            .options(_LOAD_PARTICIPANT, joinedload(Beneficiary.payouts))
            .where(
                Beneficiary.cycle_id == cycle_id,
                Beneficiary.status != BeneficiaryStatus.CANCELLED.value,
            )
        )
        return self.db.scalars(statement).unique().first()

    def get(self, beneficiary_id: uuid.UUID, organization_id: uuid.UUID) -> Beneficiary:
        statement = (
            select(Beneficiary)
            .options(_LOAD_PARTICIPANT, joinedload(Beneficiary.payouts))
            .where(Beneficiary.id == beneficiary_id)
        )
        beneficiary = self.db.scalars(statement).unique().first()
        if beneficiary is None or beneficiary.organization_id != organization_id:
            raise NotFoundError(
                "Bénéficiaire introuvable.", code="beneficiary_not_found"
            )
        return beneficiary

    def designate_manually(
        self,
        *,
        tontine: Tontine,
        cycle: TontineCycle,
        participant: TontineParticipant,
        actor: OrganizationMember,
    ) -> Beneficiary:
        """Désignation directe (mode ordre manuel ou correction encadrée)."""
        if self.of_cycle(cycle.id) is not None:
            raise ConflictError(
                "Un bénéficiaire a déjà été désigné pour cette période.",
                code="alreadyDrawn",
            )
        if participant.tontine_id != tontine.id:
            raise ValidationError(
                "Ce participant n'appartient pas à la tontine.",
                code="unknown_participant",
            )
        if participant.has_received_payout:
            raise ConflictError(
                "Ce participant a déjà reçu la cagnotte.",
                code="participant_already_served",
            )

        now = datetime.now(timezone.utc)
        beneficiary = Beneficiary(
            organization_id=tontine.organization_id,
            tontine_id=tontine.id,
            cycle_id=cycle.id,
            participant_id=participant.id,
            expected_payout_amount=cycle.expected_amount,
            source=DrawType.MANUAL.value,
            status=BeneficiaryStatus.DESIGNATED.value,
            designated_at=now,
        )
        self.db.add(beneficiary)

        participant.has_received_payout = True
        participant.is_draw_eligible = False
        participant.is_active = True
        participant.received_cycle_id = cycle.id
        cycle.status = CycleStatus.DRAWN.value

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.BENEFICIARY_DESIGNATED,
            description=(
                f"{participant.display_name} désigné(e) bénéficiaire de "
                f"{cycle.period_label} (désignation manuelle)."
            ),
            actor=actor,
            target_type="beneficiary",
            target_id=beneficiary.id,
            tontine_id=tontine.id,
            amount=cycle.expected_amount,
            metadata={"cycleId": str(cycle.id), "manual": True},
        )
        self.db.commit()
        self.db.refresh(beneficiary)
        return beneficiary

    # --- Versements ----------------------------------------------------------

    def payouts_of_tontine(self, tontine_id: uuid.UUID) -> list[Payout]:
        statement = (
            select(Payout)
            .join(Beneficiary, Beneficiary.id == Payout.beneficiary_id)
            .options(joinedload(Payout.beneficiary).options(_LOAD_PARTICIPANT))
            .where(Beneficiary.tontine_id == tontine_id)
            .order_by(Payout.created_at)
        )
        return list(self.db.scalars(statement).unique())

    def payout_of_cycle(self, cycle_id: uuid.UUID) -> Payout | None:
        statement = (
            select(Payout)
            .join(Beneficiary, Beneficiary.id == Payout.beneficiary_id)
            .options(joinedload(Payout.beneficiary).options(_LOAD_PARTICIPANT))
            .where(
                Beneficiary.cycle_id == cycle_id,
                Payout.status != PayoutStatus.FAILED.value,
            )
            .order_by(Payout.created_at.desc())
        )
        return self.db.scalars(statement).unique().first()

    def get_payout(self, payout_id: uuid.UUID, organization_id: uuid.UUID) -> Payout:
        statement = (
            select(Payout)
            .options(joinedload(Payout.beneficiary).options(_LOAD_PARTICIPANT))
            .where(Payout.id == payout_id)
        )
        payout = self.db.scalars(statement).unique().first()
        if payout is None or payout.organization_id != organization_id:
            raise NotFoundError("Versement introuvable.", code="payout_not_found")
        return payout

    def record(
        self,
        *,
        beneficiary: Beneficiary,
        amount: Decimal,
        method: PaymentMethod,
        actor: OrganizationMember,
        status: PayoutStatus = PayoutStatus.PAID,
        reference: str | None = None,
        comment: str | None = None,
        proof_url: str | None = None,
        sent_at: datetime | None = None,
    ) -> Payout:
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )
        if beneficiary.status_enum is BeneficiaryStatus.CANCELLED:
            raise ConflictError(
                "Ce bénéficiaire a été annulé.", code="beneficiary_cancelled"
            )
        existing = self.payout_of_cycle(beneficiary.cycle_id)
        if existing is not None and existing.status_enum is PayoutStatus.PAID:
            raise ConflictError(
                "La cagnotte de cette période a déjà été versée.",
                code="payout_already_recorded",
            )

        now = datetime.now(timezone.utc)
        payout = Payout(
            organization_id=beneficiary.organization_id,
            beneficiary_id=beneficiary.id,
            amount=amount,
            payment_method=method.value,
            reference=reference,
            comment=comment,
            proof_url=proof_url,
            status=status.value,
            paid_by=actor.id,
            paid_at=sent_at or now,
            confirmed_at=now if status is PayoutStatus.PAID else None,
        )
        self.db.add(payout)
        self.db.flush()

        self.audit.record(
            organization_id=beneficiary.organization_id,
            action=AuditAction.PAYOUT_RECORDED,
            description=(
                f"Versement de la cagnotte à {beneficiary.participant.display_name} "
                f"enregistré ({method.value})."
            ),
            actor=actor,
            target_type="payout",
            target_id=payout.id,
            tontine_id=beneficiary.tontine_id,
            amount=amount,
            metadata={
                "beneficiaryId": str(beneficiary.id),
                "cycleId": str(beneficiary.cycle_id),
                "status": status.value,
            },
        )

        if status is PayoutStatus.PAID:
            self._apply_confirmation(payout, beneficiary, actor)
        else:
            beneficiary.status = BeneficiaryStatus.PAYOUT_PENDING.value

        self.db.commit()
        self.db.refresh(payout)
        return payout

    def confirm(self, payout: Payout, actor: OrganizationMember) -> Payout:
        if payout.status_enum is PayoutStatus.PAID:
            return payout
        if payout.status_enum is PayoutStatus.FAILED:
            raise ConflictError(
                "Un versement en échec ne peut pas être confirmé.",
                code="payout_failed",
            )

        payout.status = PayoutStatus.PAID.value
        payout.confirmed_at = datetime.now(timezone.utc)
        self._apply_confirmation(payout, payout.beneficiary, actor)
        self.db.commit()
        self.db.refresh(payout)
        return payout

    def fail(self, payout: Payout, reason: str, actor: OrganizationMember) -> Payout:
        """Échec ou annulation : jamais de suppression, toujours une trace."""
        payout.status = PayoutStatus.FAILED.value
        payout.failure_reason = reason
        beneficiary = payout.beneficiary
        beneficiary.status = BeneficiaryStatus.DESIGNATED.value

        cycle = self.db.get(TontineCycle, beneficiary.cycle_id)
        if cycle is not None and cycle.status in {
            CycleStatus.PAID_OUT.value,
            CycleStatus.CLOSED.value,
        }:
            cycle.status = CycleStatus.DRAWN.value

        self.audit.record(
            organization_id=payout.organization_id,
            action=AuditAction.PAYOUT_RECORDED,
            description=f"Versement en échec : {reason}",
            actor=actor,
            target_type="payout",
            target_id=payout.id,
            tontine_id=beneficiary.tontine_id,
            amount=payout.amount,
            metadata={"status": PayoutStatus.FAILED.value, "reason": reason},
        )
        self.db.commit()
        self.db.refresh(payout)
        return payout

    def _close_tontine_if_finished(
        self, tontine_id: uuid.UUID, actor: OrganizationMember
    ) -> None:
        """Dernier cycle versé : la tontine se termine d'elle-même."""
        tontine = self.db.get(Tontine, tontine_id)
        if tontine is None or tontine.status != TontineStatus.ACTIVE.value:
            return

        remaining = self.db.scalars(
            select(TontineCycle.id).where(
                TontineCycle.tontine_id == tontine_id,
                TontineCycle.status.notin_(
                    [CycleStatus.PAID_OUT.value, CycleStatus.CLOSED.value]
                ),
            )
        ).first()
        if remaining is not None:
            return

        tontine.status = TontineStatus.COMPLETED.value
        tontine.closed_at = datetime.now(timezone.utc)
        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.TONTINE_STATUS_CHANGED,
            description=(
                f"Tontine « {tontine.name} » terminée : tous les cycles ont été "
                f"versés."
            ),
            actor=actor,
            target_type="tontine",
            target_id=tontine.id,
            tontine_id=tontine.id,
            metadata={"status": TontineStatus.COMPLETED.value, "automatic": True},
        )
        self.db.flush()

    def total_received_by(
        self, organization_id: uuid.UUID, member_id: uuid.UUID
    ) -> Decimal:
        total = self.db.scalar(
            select(func.coalesce(func.sum(Payout.amount), 0))
            .join(Beneficiary, Beneficiary.id == Payout.beneficiary_id)
            .join(
                TontineParticipant,
                TontineParticipant.id == Beneficiary.participant_id,
            )
            .where(
                Payout.organization_id == organization_id,
                Payout.status == PayoutStatus.PAID.value,
                TontineParticipant.organization_member_id == member_id,
            )
        )
        return Decimal(str(total or 0))

    # --- Interne -------------------------------------------------------------

    def _apply_confirmation(
        self, payout: Payout, beneficiary: Beneficiary, actor: OrganizationMember
    ) -> None:
        beneficiary.status = BeneficiaryStatus.PAID.value
        cycle = self.db.get(TontineCycle, beneficiary.cycle_id)
        if cycle is not None:
            cycle.status = CycleStatus.PAID_OUT.value
            self.db.flush()
            self._close_tontine_if_finished(beneficiary.tontine_id, actor)

        self.audit.record(
            organization_id=payout.organization_id,
            action=AuditAction.PAYOUT_CONFIRMED,
            description=(
                f"Cagnotte versée à {beneficiary.participant.display_name} "
                f"({payout.amount})."
            ),
            actor=actor,
            target_type="payout",
            target_id=payout.id,
            tontine_id=beneficiary.tontine_id,
            amount=payout.amount,
            metadata={
                "beneficiaryId": str(beneficiary.id),
                "cycleId": str(beneficiary.cycle_id),
            },
        )
        self.notifications.notify(
            user_id=beneficiary.participant.member.user_id,
            organization_id=beneficiary.organization_id,
            type_=NotificationType.PAYOUT_DONE,
            title="Cagnotte versée",
            body=f"Votre cagnotte de {payout.amount:.0f} a été versée.",
            target_route=f"/tontine/{beneficiary.tontine_id}",
            data={"payoutId": str(payout.id)},
        )
        self.db.flush()
