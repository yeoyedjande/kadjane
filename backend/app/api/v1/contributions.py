from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, CycleCtx, DbSession, OrgContext, TontineCtx
from app.core.errors import NotFoundError, ValidationError
from app.core.responses import success
from app.models.contribution import Contribution
from app.models.enums import ContributionStatus, PaymentStatus
from app.schemas import serializers as out
from app.schemas.tontine import PaymentClose, PaymentCreate
from app.services.permission_service import PermissionService
from app.services.contribution_service import ContributionService
from app.services.tontine_service import TontineService

router = APIRouter(tags=["cotisations"])


# --- Lecture ----------------------------------------------------------------


@router.get(
    "/cycles/{cycle_id}/contribution-slots",
    summary="Lignes attendues d'un cycle (payées ou non)",
)
def cycle_slots(
    db: DbSession,
    context: CycleCtx,
    cycle_id: uuid.UUID,
    search: Annotated[str, Query(description="Recherche par nom")] = "",
    status_filter: Annotated[ContributionStatus | None, Query(alias="status")] = None,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    lines = _filtered(
        ContributionService(db).for_cycle(cycle_id), search, status_filter
    )
    return success([out.contribution_slot(line) for line in lines])


@router.get("/cycles/{cycle_id}/contributions", summary="Paiements d'un cycle")
def cycle_contributions(
    db: DbSession, context: CycleCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    return success(_payments_of(ContributionService(db).for_cycle(cycle_id)))


@router.get(
    "/tontines/{tontine_id}/cycles/{cycle_id}/contributions",
    summary="Cotisations attendues d'un cycle",
)
def tontine_cycle_contributions(
    db: DbSession,
    context: TontineCtx,
    cycle_id: uuid.UUID,
    search: Annotated[str, Query()] = "",
    status_filter: Annotated[ContributionStatus | None, Query(alias="status")] = None,
) -> dict[str, Any]:
    """Vue « ce que chacun doit » : attendu, payé, restant, statut."""
    PermissionService(db).require(context.membership, "contribution.view")
    TontineService(db).cycle(cycle_id, context.organization_id)
    lines = _filtered(
        ContributionService(db).for_cycle(cycle_id), search, status_filter
    )
    expected = sum(line.expected_amount for line in lines)
    collected = sum(line.paid_amount for line in lines)
    return success(
        [out.contribution_line(line) for line in lines],
        meta={
            "expected": out.money(expected),
            "collected": out.money(collected),
            "remaining": max(0.0, out.money(expected) - out.money(collected)),
            "paid_count": sum(
                1 for line in lines if line.status == ContributionStatus.PAID.value
            ),
            "late_count": sum(
                1 for line in lines if line.status == ContributionStatus.LATE.value
            ),
            "total": len(lines),
        },
    )


@router.get("/tontines/{tontine_id}/contributions", summary="Paiements d'une tontine")
def tontine_contributions(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    return success(_payments_of(ContributionService(db).for_tontine(context.tontine.id)))


@router.get(
    "/organizations/{organization_id}/members/{member_id}/contributions",
    summary="Cotisations d'un membre",
)
def member_contributions(
    db: DbSession, context: OrgContext, member_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    lines = ContributionService(db).for_member(context.organization_id, member_id)
    return success(_payments_of(lines))


# --- Écriture ---------------------------------------------------------------


@router.post(
    "/tontines/{tontine_id}/contributions",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un paiement de cotisation",
)
def record_contribution(
    db: DbSession, context: TontineCtx, payload: PaymentCreate
) -> dict[str, Any]:
    """Route du contrat mobile : le paiement vise un membre et un cycle."""
    PermissionService(db).require(context.membership, "contribution.record")
    service = ContributionService(db)

    if payload.contribution_id is not None:
        contribution = service.get(payload.contribution_id, context.organization_id)
    elif payload.cycle_id is not None and payload.member_id is not None:
        TontineService(db).cycle(payload.cycle_id, context.organization_id)
        contribution = service.find_for_member(payload.cycle_id, payload.member_id)
    else:
        raise ValidationError(
            "Indiquez `contributionId`, ou `cycleId` et `memberId`.",
            code="missing_contribution_target",
        )

    payment = service.record_payment(
        contribution=contribution,
        amount=payload.amount,
        method=payload.method,
        actor=context.membership,
        status=payload.status,
        reference=payload.reference,
        comment=payload.comment,
        proof_url=payload.proof_url,
        paid_at=payload.paid_at,
    )
    return success(out.payment_as_contribution(payment, contribution))


@router.post(
    "/contributions/{contribution_id}/payments",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un paiement sur une cotisation",
)
def record_payment(
    db: DbSession,
    user: CurrentUser,
    contribution_id: uuid.UUID,
    payload: PaymentCreate,
) -> dict[str, Any]:
    """Route du cahier des charges : la cotisation est dans l'URL."""
    contribution, context = _guarded_contribution(
        db, user, contribution_id, "contribution.record"
    )
    service = ContributionService(db)
    payment = service.record_payment(
        contribution=contribution,
        amount=payload.amount,
        method=payload.method,
        actor=context.membership,
        status=payload.status,
        reference=payload.reference,
        comment=payload.comment,
        proof_url=payload.proof_url,
        paid_at=payload.paid_at,
    )
    return success(out.payment_as_contribution(payment, contribution))


@router.post("/contributions/{payment_id}/confirm", summary="Confirmer un paiement")
def confirm_contribution(
    db: DbSession, user: CurrentUser, payment_id: uuid.UUID
) -> dict[str, Any]:
    payment, context = _guarded_payment(db, user, payment_id, "contribution.confirm")
    confirmed = ContributionService(db).confirm_payment(payment, context.membership)
    return success(out.payment_as_contribution(confirmed, confirmed.contribution))


@router.post("/contributions/{payment_id}/cancel", summary="Annuler un paiement")
def cancel_contribution(
    db: DbSession, user: CurrentUser, payment_id: uuid.UUID, payload: PaymentClose
) -> dict[str, Any]:
    payment, context = _guarded_payment(db, user, payment_id, "contribution.cancel")
    closed = ContributionService(db).close_payment(
        payment,
        status=PaymentStatus.CANCELLED,
        reason=payload.reason,
        actor=context.membership,
    )
    return success(out.payment_as_contribution(closed, closed.contribution))


@router.post("/contributions/{payment_id}/reject", summary="Rejeter un paiement")
def reject_contribution(
    db: DbSession, user: CurrentUser, payment_id: uuid.UUID, payload: PaymentClose
) -> dict[str, Any]:
    payment, context = _guarded_payment(db, user, payment_id, "contribution.cancel")
    closed = ContributionService(db).close_payment(
        payment,
        status=PaymentStatus.REJECTED,
        reason=payload.reason,
        actor=context.membership,
    )
    return success(out.payment_as_contribution(closed, closed.contribution))


# --- Interne ----------------------------------------------------------------


def _payments_of(lines: list[Contribution]) -> list[dict[str, Any]]:
    """Aplatit les cotisations en la liste de paiements attendue par le client."""
    payments: list[dict[str, Any]] = []
    for line in lines:
        payments.extend(
            out.payment_as_contribution(payment, line) for payment in line.payments
        )
    payments.sort(key=lambda item: item["recordedAt"] or "", reverse=True)
    return payments


def _filtered(
    lines: list[Contribution],
    search: str,
    status_filter: ContributionStatus | None,
) -> list[Contribution]:
    result = lines
    term = search.strip().lower()
    if term:
        result = [
            line
            for line in result
            if term in line.participant.display_name.lower()
        ]
    if status_filter is not None:
        result = [line for line in result if line.status == status_filter.value]
    return result


def _guarded_contribution(
    db: DbSession, user: CurrentUser, contribution_id: uuid.UUID, permission: str
):
    from app.core.deps import get_organization_context

    contribution = db.get(Contribution, contribution_id)
    if contribution is None:
        raise NotFoundError("Cotisation introuvable.", code="contribution_not_found")
    context = get_organization_context(db, user, contribution.organization_id)
    PermissionService(db).require(context.membership, permission)
    return contribution, context


def _guarded_payment(
    db: DbSession, user: CurrentUser, payment_id: uuid.UUID, permission: str
):
    from app.core.deps import get_organization_context
    from app.models.contribution import Payment

    payment = db.get(Payment, payment_id)
    if payment is None:
        raise NotFoundError("Paiement introuvable.", code="payment_not_found")
    context = get_organization_context(db, user, payment.organization_id)
    PermissionService(db).require(context.membership, permission)
    return payment, context
