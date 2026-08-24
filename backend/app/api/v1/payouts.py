from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, status

from app.core.deps import CurrentUser, CycleCtx, DbSession, OrgContext, TontineCtx
from app.core.errors import NotFoundError, ValidationError
from app.core.responses import success
from app.models.payout import Beneficiary, Payout
from app.models.tontine import TontineParticipant
from app.schemas import serializers as out
from app.schemas.tontine import BeneficiaryDesignate, PayoutClose, PayoutCreate
from app.services.permission_service import PermissionService
from app.services.payout_service import PayoutService
from app.services.tontine_service import TontineService

router = APIRouter(tags=["bénéficiaires et versements"])


# --- Bénéficiaires -----------------------------------------------------------


@router.get("/tontines/{tontine_id}/beneficiaries", summary="Bénéficiaires")
def list_beneficiaries(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "payout.view")
    beneficiaries = PayoutService(db).for_tontine(context.tontine.id)
    return success([out.beneficiary(b) for b in beneficiaries])


@router.get("/cycles/{cycle_id}/beneficiary", summary="Bénéficiaire d'un cycle")
def read_cycle_beneficiary(
    db: DbSession, context: CycleCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "payout.view")
    beneficiary = PayoutService(db).of_cycle(cycle_id)
    return success(out.beneficiary(beneficiary) if beneficiary else None)


@router.post(
    "/cycles/{cycle_id}/beneficiary",
    status_code=status.HTTP_201_CREATED,
    summary="Désigner manuellement un bénéficiaire",
)
def designate_beneficiary(
    db: DbSession,
    context: CycleCtx,
    cycle_id: uuid.UUID,
    payload: BeneficiaryDesignate,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "draw.override")
    service = TontineService(db)
    cycle = service.cycle(cycle_id, context.organization_id)
    participant = db.get(TontineParticipant, payload.participant_id)
    if participant is None:
        raise ValidationError(
            "Participant introuvable.", code="unknown_participant"
        )
    beneficiary = PayoutService(db).designate_manually(
        tontine=context.tontine,
        cycle=cycle,
        participant=participant,
        actor=context.membership,
    )
    return success(out.beneficiary(beneficiary))


@router.get("/beneficiaries/{beneficiary_id}", summary="Détail d'un bénéficiaire")
def read_beneficiary(
    db: DbSession, user: CurrentUser, beneficiary_id: uuid.UUID
) -> dict[str, Any]:
    beneficiary, _ = _guarded_beneficiary(db, user, beneficiary_id, "payout.view")
    return success(out.beneficiary(beneficiary))


# --- Versements --------------------------------------------------------------


@router.get("/tontines/{tontine_id}/payouts", summary="Versements d'une tontine")
def list_payouts(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "payout.view")
    payouts = PayoutService(db).payouts_of_tontine(context.tontine.id)
    return success([out.payout(p) for p in payouts])


@router.get("/cycles/{cycle_id}/payout", summary="Versement d'un cycle")
def read_cycle_payout(
    db: DbSession, context: CycleCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "payout.view")
    payout = PayoutService(db).payout_of_cycle(cycle_id)
    return success(out.payout(payout) if payout else None)


@router.post(
    "/payouts",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un versement de cagnotte",
)
def record_payout(
    db: DbSession, user: CurrentUser, payload: PayoutCreate
) -> dict[str, Any]:
    if payload.beneficiary_id is None:
        raise ValidationError(
            "`beneficiaryId` est obligatoire.", code="beneficiary_required"
        )
    beneficiary, context = _guarded_beneficiary(
        db, user, payload.beneficiary_id, "payout.record"
    )
    payout = PayoutService(db).record(
        beneficiary=beneficiary,
        amount=payload.amount,
        method=payload.method,
        actor=context.membership,
        status=payload.status,
        reference=payload.reference,
        comment=payload.comment,
        proof_url=payload.proof_url,
        sent_at=payload.sent_at,
    )
    return success(out.payout(payout))


@router.post("/payouts/{payout_id}/confirm", summary="Confirmer un versement")
def confirm_payout(
    db: DbSession, user: CurrentUser, payout_id: uuid.UUID
) -> dict[str, Any]:
    payout, context = _guarded_payout(db, user, payout_id, "payout.record")
    confirmed = PayoutService(db).confirm(payout, context.membership)
    return success(out.payout(confirmed))


@router.post("/payouts/{payout_id}/fail", summary="Marquer un versement en échec")
def fail_payout(
    db: DbSession, user: CurrentUser, payout_id: uuid.UUID, payload: PayoutClose
) -> dict[str, Any]:
    payout, context = _guarded_payout(db, user, payout_id, "payout.record")
    failed = PayoutService(db).fail(payout, payload.reason, context.membership)
    return success(out.payout(failed))


@router.get(
    "/organizations/{organization_id}/members/{member_id}/payouts/total",
    summary="Total reçu par un membre",
)
def member_payout_total(
    db: DbSession, context: OrgContext, member_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "payout.view")
    total = PayoutService(db).total_received_by(context.organization_id, member_id)
    return success({"total": out.money(total)})


# --- Interne ----------------------------------------------------------------


def _guarded_beneficiary(
    db: DbSession, user: CurrentUser, beneficiary_id: uuid.UUID, permission: str
):
    from app.core.deps import get_organization_context

    beneficiary = db.get(Beneficiary, beneficiary_id)
    if beneficiary is None:
        raise NotFoundError("Bénéficiaire introuvable.", code="beneficiary_not_found")
    context = get_organization_context(db, user, beneficiary.organization_id)
    PermissionService(db).require(context.membership, permission)
    return beneficiary, context


def _guarded_payout(
    db: DbSession, user: CurrentUser, payout_id: uuid.UUID, permission: str
):
    from app.core.deps import get_organization_context

    payout = db.get(Payout, payout_id)
    if payout is None:
        raise NotFoundError("Versement introuvable.", code="payout_not_found")
    context = get_organization_context(db, user, payout.organization_id)
    PermissionService(db).require(context.membership, permission)
    return payout, context
