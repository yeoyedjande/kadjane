"""Tirage au sort — décidé par le serveur, jamais par l'application.

Garanties :

1. La liste des éligibles est **reconstruite depuis PostgreSQL** ; rien de ce
   que le client envoie n'influence la sélection.
2. Le gagnant est tiré avec `secrets.choice` (générateur cryptographique).
   Une graine transmise par le client est ignorée : elle ne doit jamais
   permettre de prédire ou de forcer un résultat.
3. L'opération est transactionnelle et verrouillée : le cycle est verrouillé
   (`SELECT … FOR UPDATE`) et un index unique partiel interdit deux tirages
   `completed` sur un même cycle. Double clic, rejeu réseau ou requêtes
   simultanées ne peuvent pas produire deux bénéficiaires.
4. Rien n'est supprimé : un tirage se `cancel` ou s'`invalidate`.
"""

from __future__ import annotations

import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, PermissionDeniedError
from app.models.contribution import Contribution
from app.models.draw import DrawParticipant, DrawSession
from app.models.enums import (
    AllocationMode,
    AuditAction,
    BeneficiaryStatus,
    ContributionStatus,
    CycleStatus,
    DrawStatus,
    DrawType,
    NotificationType,
    TontineStatus,
)
from app.models.membership import OrganizationMember
from app.models.payout import Beneficiary
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.services import permission_service
from app.services.audit_service import AuditService
from app.services.contribution_service import ContributionService
from app.services.notification_service import NotificationService

RANDOM_SOURCE = "server_secrets_choice"


@dataclass(slots=True)
class Eligibility:
    """Évaluation des conditions du tirage d'un cycle."""

    allowed: bool
    reason: str
    missing_contributions: int
    remaining_amount: Decimal
    can_override: bool
    participants_count: int
    eligible: list[TontineParticipant]


class DrawService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)
        self.contributions = ContributionService(db)
        self.notifications = NotificationService(db)

    # --- Lecture -------------------------------------------------------------

    def eligible_participants(
        self, tontine: Tontine, cycle: TontineCycle
    ) -> list[TontineParticipant]:
        """Éligibles reconstruits depuis la base, pour ce cycle.

        Un ancien bénéficiaire reste `is_active` — il continue de cotiser —
        mais sort définitivement de la roue.
        """
        statement = (
            select(TontineParticipant)
            .options(
                joinedload(TontineParticipant.member).joinedload(
                    OrganizationMember.user
                )
            )
            .where(
                TontineParticipant.tontine_id == tontine.id,
                TontineParticipant.is_active.is_(True),
                TontineParticipant.is_draw_eligible.is_(True),
                TontineParticipant.has_received_payout.is_(False),
            )
            .order_by(TontineParticipant.joined_at)
        )
        participants = list(self.db.scalars(statement).unique())

        if tontine.mode.has_predefined_order:
            # Ordre figé : le bénéficiaire du cycle est celui dont la position
            # correspond au rang du cycle.
            expected = [
                p for p in participants if p.draw_position == cycle.sequence_number
            ]
            return expected or participants
        return participants

    def evaluate(self, tontine: Tontine, cycle: TontineCycle) -> Eligibility:
        participants_count = int(
            self.db.scalar(
                select(func.count())
                .select_from(TontineParticipant)
                .where(
                    TontineParticipant.tontine_id == tontine.id,
                    TontineParticipant.is_active.is_(True),
                )
            )
            or 0
        )

        eligible = self.eligible_participants(tontine, cycle)
        missing_count, remaining = self.contributions.missing_for_cycle(cycle.id)
        can_override = bool(tontine.allow_draw_override)

        def result(allowed: bool, reason: str) -> Eligibility:
            return Eligibility(
                allowed=allowed,
                reason=reason,
                missing_contributions=missing_count,
                remaining_amount=remaining,
                can_override=can_override,
                participants_count=participants_count,
                eligible=eligible,
            )

        if tontine.status_enum is not TontineStatus.ACTIVE:
            return result(False, "tontineNotActive")
        if self.completed_draw_of(cycle.id) is not None:
            return result(False, "alreadyDrawn")
        if not eligible:
            return result(False, "noEligibleParticipant")
        if tontine.require_all_contributions_before_draw and missing_count > 0:
            return result(False, "missingContributions")
        return result(True, "none")

    def completed_draw_of(self, cycle_id: uuid.UUID) -> DrawSession | None:
        return self.db.scalars(
            select(DrawSession)
            .options(joinedload(DrawSession.entries))
            .where(
                DrawSession.cycle_id == cycle_id,
                DrawSession.status == DrawStatus.COMPLETED.value,
            )
        ).first()

    def history(self, tontine_id: uuid.UUID) -> list[DrawSession]:
        statement = (
            select(DrawSession)
            .options(joinedload(DrawSession.entries))
            .where(DrawSession.tontine_id == tontine_id)
            .order_by(DrawSession.created_at.desc())
        )
        return list(self.db.scalars(statement).unique())

    def get(self, draw_id: uuid.UUID, organization_id: uuid.UUID) -> DrawSession:
        session = self.db.get(DrawSession, draw_id)
        if session is None or session.organization_id != organization_id:
            raise NotFoundError("Tirage introuvable.", code="draw_not_found")
        return session

    # --- Tirage --------------------------------------------------------------

    def run(
        self,
        *,
        tontine: Tontine,
        cycle: TontineCycle,
        actor: OrganizationMember,
        override: bool = False,
        override_reason: str | None = None,
    ) -> DrawSession:
        """Exécute le tirage du cycle. Transactionnel de bout en bout."""
        permission_service.require(actor.role_enum, "draw.run")

        # Verrou de ligne : deux requêtes simultanées se sérialisent ici.
        locked = self.db.scalars(
            select(TontineCycle).where(TontineCycle.id == cycle.id).with_for_update()
        ).first()
        cycle = locked or cycle

        evaluation = self.evaluate(tontine, cycle)

        if evaluation.reason == "alreadyDrawn":
            raise ConflictError(
                "Un bénéficiaire a déjà été désigné pour cette période.",
                code="alreadyDrawn",
            )
        if evaluation.reason == "tontineNotActive":
            raise ConflictError(
                "La tontine n'est pas active.", code="tontineNotActive"
            )
        if evaluation.reason == "noEligibleParticipant":
            raise ConflictError(
                "Plus aucun participant n'est éligible au tirage.",
                code="noEligibleParticipant",
            )

        if evaluation.reason == "missingContributions":
            self._authorize_override(
                tontine=tontine,
                actor=actor,
                override=override,
                reason=override_reason,
                evaluation=evaluation,
            )

        winner = self._select_winner(tontine, cycle, evaluation.eligible)
        now = datetime.now(timezone.utc)

        session = DrawSession(
            organization_id=tontine.organization_id,
            tontine_id=tontine.id,
            cycle_id=cycle.id,
            draw_type=(
                DrawType.PERIODIC.value
                if tontine.mode is AllocationMode.MONTHLY_DRAW
                else DrawType.MANUAL.value
                if tontine.mode is AllocationMode.MANUAL_ORDER
                else DrawType.FULL_ORDER.value
            ),
            status=DrawStatus.COMPLETED.value,
            period_label=cycle.period_label,
            winner_participant_id=winner.id,
            drawn_by=actor.id,
            override_used=bool(override and evaluation.reason == "missingContributions"),
            override_reason=(
                override_reason
                if override and evaluation.reason == "missingContributions"
                else None
            ),
            proof_reference=_proof_reference(),
            random_source=RANDOM_SOURCE,
            completed_at=now,
        )
        self.db.add(session)
        self.db.flush()

        for position, participant in enumerate(evaluation.eligible, start=1):
            self.db.add(
                DrawParticipant(
                    draw_session_id=session.id,
                    participant_id=participant.id,
                    display_name=participant.display_name,
                    was_eligible=True,
                    position=position,
                    weight=1,
                )
            )

        # Le gagnant sort de la roue mais reste actif : il continue de cotiser.
        winner.has_received_payout = True
        winner.is_draw_eligible = False
        winner.is_active = True
        winner.received_cycle_id = cycle.id

        beneficiary = Beneficiary(
            organization_id=tontine.organization_id,
            tontine_id=tontine.id,
            cycle_id=cycle.id,
            participant_id=winner.id,
            draw_session_id=session.id,
            expected_payout_amount=cycle.expected_amount,
            source=session.draw_type,
            status=BeneficiaryStatus.DESIGNATED.value,
            designated_at=now,
        )
        self.db.add(beneficiary)

        cycle.status = CycleStatus.DRAWN.value

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.DRAW_COMPLETED,
            description=(
                f"{winner.display_name} a été tiré(e) comme bénéficiaire de "
                f"{cycle.period_label}."
            ),
            actor=actor,
            target_type="draw",
            target_id=session.id,
            tontine_id=tontine.id,
            amount=cycle.expected_amount,
            metadata={
                "proof": session.proof_reference,
                "cycleId": str(cycle.id),
                "eligibleCount": len(evaluation.eligible),
                "randomSource": RANDOM_SOURCE,
            },
        )
        if session.override_used:
            self.audit.record(
                organization_id=tontine.organization_id,
                action=AuditAction.DRAW_OVERRIDDEN,
                description=f"Tirage forcé de {cycle.period_label} : {override_reason}",
                actor=actor,
                target_type="draw",
                target_id=session.id,
                tontine_id=tontine.id,
                amount=evaluation.remaining_amount,
                metadata={
                    "reason": override_reason,
                    "missingContributions": evaluation.missing_contributions,
                    "remainingAmount": float(evaluation.remaining_amount),
                },
            )
        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.BENEFICIARY_DESIGNATED,
            description=(
                f"{winner.display_name} désigné(e) bénéficiaire de {cycle.period_label}."
            ),
            actor=actor,
            target_type="beneficiary",
            target_id=beneficiary.id,
            tontine_id=tontine.id,
            amount=cycle.expected_amount,
            metadata={"cycleId": str(cycle.id), "drawId": str(session.id)},
        )

        self._notify_result(tontine, cycle, winner, evaluation.eligible)

        try:
            self.db.commit()
        except IntegrityError as error:
            # Filet de sécurité de la base : un second tirage concurrent a
            # gagné la course. Aucun doublon n'est créé.
            self.db.rollback()
            raise ConflictError(
                "Un bénéficiaire a déjà été désigné pour cette période.",
                code="alreadyDrawn",
            ) from error

        self.db.refresh(session)
        return session

    def generate_full_order(
        self,
        *,
        tontine: Tontine,
        actor: OrganizationMember,
        commit: bool = True,
    ) -> DrawSession:
        """Mode B : un tirage unique fixe l'ordre de passage complet."""
        participants = list(
            self.db.scalars(
                select(TontineParticipant)
                .options(
                    joinedload(TontineParticipant.member).joinedload(
                        OrganizationMember.user
                    )
                )
                .where(
                    TontineParticipant.tontine_id == tontine.id,
                    TontineParticipant.is_active.is_(True),
                )
            ).unique()
        )
        if any(p.draw_position is not None for p in participants):
            raise ConflictError(
                "L'ordre de passage est déjà défini.", code="orderAlreadyDefined"
            )
        if not participants:
            raise ConflictError(
                "Aucun participant éligible.", code="noEligibleParticipant"
            )

        # Mélange cryptographique : l'ordre n'est ni prévisible ni rejouable.
        shuffled = list(participants)
        secrets.SystemRandom().shuffle(shuffled)

        now = datetime.now(timezone.utc)
        session = DrawSession(
            organization_id=tontine.organization_id,
            tontine_id=tontine.id,
            cycle_id=None,
            draw_type=DrawType.FULL_ORDER.value,
            status=DrawStatus.COMPLETED.value,
            period_label=f"Ordre de passage — {tontine.name}",
            drawn_by=actor.id,
            proof_reference=_proof_reference(),
            random_source=RANDOM_SOURCE,
            completed_at=now,
        )
        self.db.add(session)
        self.db.flush()

        for position, participant in enumerate(shuffled, start=1):
            participant.draw_position = position
            self.db.add(
                DrawParticipant(
                    draw_session_id=session.id,
                    participant_id=participant.id,
                    display_name=participant.display_name,
                    was_eligible=True,
                    position=position,
                    weight=1,
                )
            )

        self.audit.record(
            organization_id=tontine.organization_id,
            action=AuditAction.ORDER_GENERATED,
            description=f"Ordre de passage tiré au sort ({len(shuffled)} participants).",
            actor=actor,
            target_type="draw",
            target_id=session.id,
            tontine_id=tontine.id,
            metadata={
                "proof": session.proof_reference,
                "order": [p.display_name for p in shuffled],
            },
        )

        if commit:
            self.db.commit()
            self.db.refresh(session)
        return session

    def cancel(
        self, session: DrawSession, reason: str, actor: OrganizationMember
    ) -> DrawSession:
        if session.status_enum is DrawStatus.COMPLETED:
            raise ConflictError(
                "Un tirage validé s'invalide, il ne s'annule pas.",
                code="draw_completed",
            )
        session.status = DrawStatus.CANCELLED.value
        session.closed_at = datetime.now(timezone.utc)
        session.close_reason = reason

        self.audit.record(
            organization_id=session.organization_id,
            action=AuditAction.DRAW_CANCELLED,
            description=f"Tirage annulé : {reason}",
            actor=actor,
            target_type="draw",
            target_id=session.id,
            tontine_id=session.tontine_id,
            metadata={"reason": reason},
        )
        self.db.commit()
        self.db.refresh(session)
        return session

    def invalidate(
        self, session: DrawSession, reason: str, actor: OrganizationMember
    ) -> DrawSession:
        """Le tirage est conservé, marqué invalidé ; le cycle repart en collecte."""
        permission_service.require(actor.role_enum, "draw.invalidate")
        if session.status_enum is not DrawStatus.COMPLETED:
            raise ConflictError(
                "Seul un tirage validé peut être invalidé.", code="draw_not_completed"
            )

        session.status = DrawStatus.INVALIDATED.value
        session.closed_at = datetime.now(timezone.utc)
        session.close_reason = reason

        if session.winner_participant_id is not None:
            winner = self.db.get(TontineParticipant, session.winner_participant_id)
            if winner is not None:
                winner.has_received_payout = False
                winner.is_draw_eligible = True
                winner.received_cycle_id = None

        beneficiary = self.db.scalars(
            select(Beneficiary).where(Beneficiary.draw_session_id == session.id)
        ).first()
        if beneficiary is not None:
            beneficiary.status = BeneficiaryStatus.CANCELLED.value
            beneficiary.cancel_reason = reason

        if session.cycle_id is not None:
            cycle = self.db.get(TontineCycle, session.cycle_id)
            if cycle is not None:
                cycle.status = CycleStatus.COLLECTING.value
                self.db.flush()
                self.contributions.recompute_cycle(cycle.id)

        self.audit.record(
            organization_id=session.organization_id,
            action=AuditAction.DRAW_INVALIDATED,
            description=f"Tirage invalidé : {reason}",
            actor=actor,
            target_type="draw",
            target_id=session.id,
            tontine_id=session.tontine_id,
            metadata={"reason": reason},
        )
        self.db.commit()
        self.db.refresh(session)
        return session

    def _notify_result(
        self,
        tontine: Tontine,
        cycle: TontineCycle,
        winner: TontineParticipant,
        eligible: list[TontineParticipant],
    ) -> None:
        """Le gagnant et les autres participants apprennent le résultat."""
        self.notifications.notify(
            user_id=winner.member.user_id,
            organization_id=tontine.organization_id,
            type_=NotificationType.DRAW_RESULT,
            title="Vous êtes bénéficiaire !",
            body=(
                f"Vous recevez la cagnotte de {cycle.period_label} "
                f"({cycle.expected_amount:.0f})."
            ),
            target_route=f"/tontine/{tontine.id}",
            data={"cycleId": str(cycle.id), "winner": "true"},
        )
        for participant in eligible:
            if participant.id == winner.id:
                continue
            self.notifications.notify(
                user_id=participant.member.user_id,
                organization_id=tontine.organization_id,
                type_=NotificationType.DRAW_RESULT,
                title=f"Tirage de {cycle.period_label}",
                body=f"{winner.display_name} est le bénéficiaire de la période.",
                target_route=f"/tontine/{tontine.id}",
                data={"cycleId": str(cycle.id)},
            )

    # --- Interne -------------------------------------------------------------

    def _authorize_override(
        self,
        *,
        tontine: Tontine,
        actor: OrganizationMember,
        override: bool,
        reason: str | None,
        evaluation: Eligibility,
    ) -> None:
        details = {
            "remaining_count": evaluation.missing_contributions,
            "remaining_amount": float(evaluation.remaining_amount),
            "missingContributions": evaluation.missing_contributions,
        }
        if not override:
            raise ConflictError(
                _missing_message(evaluation.missing_contributions),
                code="missingContributions",
                details=details,
            )
        if not tontine.allow_draw_override:
            raise ConflictError(
                "Le forçage du tirage est désactivé pour cette tontine.",
                code="override_disabled",
                details=details,
            )
        permission_service.require(actor.role_enum, "draw.override")
        if not reason or not reason.strip():
            raise ConflictError(
                "Une justification est obligatoire pour forcer le tirage.",
                code="override_reason_required",
                details=details,
            )

    def _select_winner(
        self,
        tontine: Tontine,
        cycle: TontineCycle,
        eligible: list[TontineParticipant],
    ) -> TontineParticipant:
        if tontine.mode.has_predefined_order:
            for participant in eligible:
                if participant.draw_position == cycle.sequence_number:
                    return participant
        # Générateur cryptographique : imprévisible et non influençable.
        return secrets.choice(eligible)


def _missing_message(count: int) -> str:
    if count <= 1:
        return "1 cotisation reste à régler."
    return f"{count} cotisations restent à régler."


def _proof_reference() -> str:
    return f"KDJ-{secrets.token_hex(4).upper()}"


def contributions_complete(db: Session, cycle_id: uuid.UUID) -> bool:
    """Vrai si toutes les cotisations attendues du cycle sont réglées."""
    pending = db.scalars(
        select(Contribution.id).where(
            Contribution.cycle_id == cycle_id,
            Contribution.status.notin_(
                [ContributionStatus.PAID.value, ContributionStatus.CANCELLED.value]
            ),
        )
    ).first()
    return pending is None
