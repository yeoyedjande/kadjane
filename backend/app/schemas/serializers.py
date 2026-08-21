"""Sérialisation des objets métier vers le contrat client.

Le modèle serveur et le contrat mobile ne portent pas les mêmes noms
(`sequence_number` ↔ `index`, `organization_member_id` ↔ `memberId`…). La
conversion est isolée ici : les services ignorent tout du JSON, et les
mappers Dart (`lib/data/dto/`) n'ont rien à changer.

Les clés camelCase sont celles de `docs/api-contract.md`. Quelques clés
snake_case du cahier des charges backend sont ajoutées en complément, jamais
en remplacement.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from app.models.audit import AuditLog
from app.models.contribution import Contribution, Payment
from app.models.draw import DrawSession
from app.models.enums import PaymentStatus
from app.models.payout import Beneficiary, Payout
from app.models.tontine import Tontine, TontineCycle, TontineParticipant


def money(value: Decimal | float | int | None) -> float:
    return float(value or 0)


def iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    moment = value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _date_iso(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return iso(value)
    return iso(datetime(value.year, value.month, value.day, tzinfo=timezone.utc))


# --- Tontine ----------------------------------------------------------------


def tontine(model: Tontine) -> dict[str, Any]:
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "name": model.name,
        "description": model.description,
        "contributionAmount": money(model.contribution_amount),
        "currency": model.currency,
        "frequency": model.frequency,
        "allocationMode": model.attribution_mode,
        "attributionMode": model.attribution_mode,
        "startDate": _date_iso(model.start_date),
        "dueDayOfPeriod": model.due_day,
        "dueDay": model.due_day,
        "customPeriodDays": model.custom_period_days,
        "status": model.status,
        "requireAllContributionsBeforeDraw": model.require_all_contributions_before_draw,
        "allowDrawOverride": model.allow_draw_override,
        "createdBy": str(model.created_by) if model.created_by else "",
        "createdAt": iso(model.created_at),
        "activatedAt": iso(model.activated_at),
        "closedAt": iso(model.closed_at),
    }


def participant(model: TontineParticipant) -> dict[str, Any]:
    """`isActive` reste vrai après réception : seul `isEligibleForDraw` tombe."""
    return {
        "id": str(model.id),
        "tontineId": str(model.tontine_id),
        "memberId": str(model.organization_member_id),
        "organizationMemberId": str(model.organization_member_id),
        "displayName": model.display_name,
        "avatarUrl": model.member.user.avatar_url,
        "joinedAt": iso(model.joined_at),
        "isActive": model.is_active,
        "isEligibleForDraw": model.is_draw_eligible,
        "isDrawEligible": model.is_draw_eligible,
        "hasReceivedPot": model.has_received_payout,
        "hasReceivedPayout": model.has_received_payout,
        "receivedCycleId": str(model.received_cycle_id)
        if model.received_cycle_id
        else None,
        "orderPosition": model.draw_position,
        "drawPosition": model.draw_position,
    }


def cycle(
    model: TontineCycle,
    *,
    beneficiary_model: Beneficiary | None = None,
    payout_model: Payout | None = None,
    draw_session_id: str | None = None,
) -> dict[str, Any]:
    return {
        "id": str(model.id),
        "tontineId": str(model.tontine_id),
        "index": model.sequence_number,
        "sequenceNumber": model.sequence_number,
        "periodLabel": model.period_label,
        "periodStart": iso(model.start_date),
        "periodEnd": iso(model.end_date),
        "startDate": iso(model.start_date),
        "endDate": iso(model.end_date),
        "dueDate": iso(model.due_date),
        "expectedAmount": money(model.expected_amount),
        "collectedAmount": money(model.collected_amount),
        "remainingAmount": max(
            0.0, money(model.expected_amount) - money(model.collected_amount)
        ),
        "status": model.status,
        "beneficiaryParticipantId": str(beneficiary_model.participant_id)
        if beneficiary_model
        else None,
        "beneficiaryId": str(beneficiary_model.id) if beneficiary_model else None,
        "drawSessionId": draw_session_id
        or (
            str(beneficiary_model.draw_session_id)
            if beneficiary_model and beneficiary_model.draw_session_id
            else None
        ),
        "payoutId": str(payout_model.id) if payout_model else None,
        "drawScheduledAt": iso(model.draw_scheduled_at),
    }


def tontine_summary(
    model: Tontine,
    *,
    participant_count: int,
    completed_cycles: int,
    total_cycles: int,
    current_cycle: TontineCycle | None,
    collected_current: Decimal,
    expected_current: Decimal,
    current_beneficiary_name: str | None,
    previous_beneficiary_name: str | None,
    current_cycle_payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "tontine": tontine(model),
        "participantCount": participant_count,
        "completedCycles": completed_cycles,
        "totalCycles": total_cycles,
        "collectedCurrentCycle": money(collected_current),
        "expectedCurrentCycle": money(expected_current),
        "currentCycle": current_cycle_payload
        or (cycle(current_cycle) if current_cycle else None),
        "currentBeneficiaryName": current_beneficiary_name,
        "previousBeneficiaryName": previous_beneficiary_name,
    }


# --- Cotisations et paiements ------------------------------------------------


def latest_payment(model: Contribution) -> Payment | None:
    """Paiement représentatif d'une cotisation : le confirmé, sinon le dernier."""
    payments = [
        p for p in model.payments if p.status_enum is not PaymentStatus.CANCELLED
    ]
    if not payments:
        return None
    confirmed = [p for p in payments if p.status_enum is PaymentStatus.CONFIRMED]
    pool = confirmed or payments
    return max(pool, key=lambda p: p.created_at)


def payment_as_contribution(
    payment_model: Payment, contribution_model: Contribution
) -> dict[str, Any]:
    """Vue « cotisation » du contrat client : un paiement replacé dans son contexte.

    Le modèle serveur sépare la ligne attendue (`contributions`) du versement
    (`payments`) ; l'application, elle, manipule un objet unique.
    """
    member = contribution_model.participant.member
    return {
        "id": str(payment_model.id),
        "organizationId": str(contribution_model.organization_id),
        "tontineId": str(contribution_model.tontine_id),
        "cycleId": str(contribution_model.cycle_id),
        "contributionId": str(contribution_model.id),
        "participantId": str(contribution_model.participant_id),
        "memberId": str(member.id),
        "memberName": contribution_model.participant.display_name,
        "amount": money(payment_model.amount),
        "status": payment_model.status,
        "method": payment_model.payment_method,
        "paymentMethod": payment_model.payment_method,
        "reference": payment_model.reference,
        "comment": payment_model.comment,
        "attachmentId": payment_model.proof_url,
        "proofUrl": payment_model.proof_url,
        "paidAt": iso(payment_model.paid_at),
        "recordedBy": str(payment_model.recorded_by)
        if payment_model.recorded_by
        else None,
        "recordedAt": iso(payment_model.created_at),
        "cancelledAt": iso(payment_model.cancelled_at),
        "cancelReason": payment_model.cancel_reason,
    }


def contribution_line(model: Contribution) -> dict[str, Any]:
    """Ligne attendue : ce que le participant doit, ce qu'il a payé."""
    member = model.participant.member
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "tontineId": str(model.tontine_id),
        "cycleId": str(model.cycle_id),
        "participantId": str(model.participant_id),
        "memberId": str(member.id),
        "memberName": model.participant.display_name,
        "avatarUrl": member.user.avatar_url,
        "expectedAmount": money(model.expected_amount),
        "paidAmount": money(model.paid_amount),
        "remainingAmount": money(model.remaining_amount),
        "status": model.status,
        "dueDate": iso(model.due_date),
        "hasReceivedPot": model.participant.has_received_payout,
        "payments": [
            payment_as_contribution(payment, model) for payment in model.payments
        ],
    }


def contribution_slot(model: Contribution) -> dict[str, Any]:
    """Une ligne par participant attendu, payée ou non."""
    payment_model = latest_payment(model)
    member = model.participant.member
    return {
        "memberId": str(member.id),
        "memberName": model.participant.display_name,
        "avatarUrl": member.user.avatar_url,
        "expectedAmount": money(model.expected_amount),
        "paidAmount": money(model.paid_amount),
        "status": model.status,
        "contributionId": str(model.id),
        "contribution": payment_as_contribution(payment_model, model)
        if payment_model
        else None,
    }


# --- Tirage ------------------------------------------------------------------


def draw_session(model: DrawSession) -> dict[str, Any]:
    winner = model.winner
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "tontineId": str(model.tontine_id),
        "cycleId": str(model.cycle_id) if model.cycle_id else "",
        "periodLabel": model.period_label,
        "drawType": model.draw_type,
        "participants": [
            {
                "participantId": str(entry.participant_id),
                "memberId": str(entry.participant.organization_member_id),
                "displayName": entry.display_name,
                "weight": entry.weight,
                "wasEligible": entry.was_eligible,
            }
            for entry in sorted(model.entries, key=lambda e: e.position)
        ],
        "status": model.status,
        "scheduledAt": iso(model.scheduled_at),
        "executedAt": iso(model.completed_at),
        "completedAt": iso(model.completed_at),
        "createdAt": iso(model.created_at),
        "winnerParticipantId": str(model.winner_participant_id)
        if model.winner_participant_id
        else None,
        "winnerMemberId": str(winner.organization_member_id) if winner else None,
        "winnerName": winner.display_name if winner else None,
        "launchedByMemberId": str(model.drawn_by) if model.drawn_by else None,
        "launchedByName": None,
        "proofReference": model.proof_reference,
        "randomSourceLabel": model.random_source,
        "seed": model.seed,
        "overrideUsed": model.override_used,
        "overrideReason": model.override_reason,
        "closedAt": iso(model.closed_at),
        "closeReason": model.close_reason,
    }


def eligibility(evaluation: Any, *, tontine_model: Tontine) -> dict[str, Any]:
    """Sortie double : contrat mobile **et** vocabulaire du cahier des charges."""
    eligible = [
        {
            "participantId": str(p.id),
            "memberId": str(p.organization_member_id),
            "displayName": p.display_name,
            "weight": 1,
        }
        for p in evaluation.eligible
    ]
    return {
        # Contrat mobile
        "allowed": evaluation.allowed,
        "reason": evaluation.reason,
        "missingContributions": evaluation.missing_contributions,
        "canOverride": evaluation.can_override,
        # Cahier des charges backend
        "can_draw": evaluation.allowed,
        "participants_count": evaluation.participants_count,
        "eligible_count": len(eligible),
        "eligible_participants": eligible,
        "remaining_contributions": evaluation.missing_contributions,
        "remaining_amount": money(evaluation.remaining_amount),
        "override_allowed": evaluation.can_override
        and bool(tontine_model.allow_draw_override),
    }


# --- Bénéficiaires et versements ---------------------------------------------


def beneficiary(model: Beneficiary, *, payout_model: Payout | None = None) -> dict[str, Any]:
    member = model.participant.member
    paid = payout_model or next(
        (p for p in model.payouts if p.status == "paid"),
        model.payouts[-1] if model.payouts else None,
    )
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "tontineId": str(model.tontine_id),
        "cycleId": str(model.cycle_id),
        "participantId": str(model.participant_id),
        "memberId": str(member.id),
        "memberName": model.participant.display_name,
        "avatarUrl": member.user.avatar_url,
        "amount": money(model.expected_payout_amount),
        "expectedPayoutAmount": money(model.expected_payout_amount),
        "designatedAt": iso(model.designated_at),
        "source": model.source,
        "status": model.status,
        "drawSessionId": str(model.draw_session_id) if model.draw_session_id else None,
        "payoutId": str(paid.id) if paid else None,
    }


def payout(model: Payout) -> dict[str, Any]:
    beneficiary_model = model.beneficiary
    member = beneficiary_model.participant.member
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "tontineId": str(beneficiary_model.tontine_id),
        "cycleId": str(beneficiary_model.cycle_id),
        "beneficiaryId": str(model.beneficiary_id),
        "memberId": str(member.id),
        "memberName": beneficiary_model.participant.display_name,
        "amount": money(model.amount),
        "status": model.status,
        "method": model.payment_method,
        "paymentMethod": model.payment_method,
        "reference": model.reference,
        "comment": model.comment,
        "attachmentId": model.proof_url,
        "proofUrl": model.proof_url,
        "sentAt": iso(model.paid_at),
        "paidAt": iso(model.paid_at),
        "confirmedAt": iso(model.confirmed_at),
        "failureReason": model.failure_reason,
        "recordedBy": str(model.paid_by) if model.paid_by else None,
        "createdAt": iso(model.created_at),
    }


# --- Audit -------------------------------------------------------------------


def audit_log(model: AuditLog) -> dict[str, Any]:
    return {
        "id": str(model.id),
        "organizationId": str(model.organization_id),
        "action": model.action,
        "description": model.description,
        "actorMemberId": str(model.actor_member_id) if model.actor_member_id else None,
        "actorName": model.actor_name,
        "targetType": model.target_type,
        "targetId": str(model.target_id) if model.target_id else None,
        "tontineId": str(model.tontine_id) if model.tontine_id else None,
        "amount": money(model.amount) if model.amount is not None else None,
        "metadata": model.audit_metadata,
        "createdAt": iso(model.created_at),
    }
