from __future__ import annotations

import uuid
from decimal import Decimal
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CycleCtx, DbSession, OrgContext, TontineCtx
from app.core.responses import success
from app.models.enums import CycleStatus, TontineStatus
from app.schemas import serializers as out
from app.schemas.tontine import (
    ParticipantOrder,
    StatusChange,
    TontineCreate,
    TontineUpdate,
)
from app.services.permission_service import PermissionService
from app.services.payout_service import PayoutService
from app.services.tontine_service import TontineService

router = APIRouter(tags=["tontines"])

_COMPLETED_CYCLES = {
    CycleStatus.DRAWN.value,
    CycleStatus.PAID_OUT.value,
    CycleStatus.CLOSED.value,
}


@router.get(
    "/organizations/{organization_id}/tontines", summary="Tontines de l'organisation"
)
def list_tontines(
    db: DbSession,
    context: OrgContext,
    status_filter: Annotated[TontineStatus | None, Query(alias="status")] = None,
    member_id: Annotated[uuid.UUID | None, Query(alias="memberId")] = None,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    service = TontineService(db)
    tontines = service.list_for_organization(
        context.organization_id, status=status_filter, member_id=member_id
    )
    return success([_summary(db, service, tontine) for tontine in tontines])


@router.post(
    "/organizations/{organization_id}/tontines",
    status_code=status.HTTP_201_CREATED,
    summary="Créer une tontine",
)
def create_tontine(
    db: DbSession, context: OrgContext, payload: TontineCreate
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.create")
    tontine = TontineService(db).create(
        organization=context.organization,
        actor=context.membership,
        name=payload.name,
        contribution_amount=payload.contribution_amount,
        currency=payload.currency,
        frequency=payload.frequency,
        attribution_mode=payload.attribution_mode,
        start_date=payload.start_date,
        due_day=payload.due_day,
        member_ids=payload.participant_ids,
        description=payload.description,
        custom_period_days=payload.custom_period_days,
        require_all_contributions_before_draw=payload.require_all_contributions_before_draw,
        allow_draw_override=payload.allow_draw_override,
        manual_order=payload.manual_order,
        activate=payload.activate,
    )
    return success(out.tontine(tontine))


@router.get("/tontines/{tontine_id}", summary="Détail d'une tontine")
def read_tontine(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    return success(out.tontine(context.tontine))


@router.get("/tontines/{tontine_id}/summary", summary="Agrégats d'une tontine")
def read_summary(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    return success(_summary(db, TontineService(db), context.tontine))


@router.patch("/tontines/{tontine_id}", summary="Mettre à jour une tontine")
def patch_tontine(
    db: DbSession, context: TontineCtx, payload: TontineUpdate
) -> dict[str, Any]:
    return _update(db, context, payload)


@router.put("/tontines/{tontine_id}", summary="Mettre à jour une tontine")
def put_tontine(
    db: DbSession, context: TontineCtx, payload: TontineUpdate
) -> dict[str, Any]:
    return _update(db, context, payload)


@router.patch("/tontines/{tontine_id}/status", summary="Changer le statut")
def change_status(
    db: DbSession, context: TontineCtx, payload: StatusChange
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.validate")
    tontine = TontineService(db).change_status(
        context.tontine, payload.status, context.membership
    )
    return success(out.tontine(tontine))


@router.get("/tontines/{tontine_id}/participants", summary="Participants")
def list_participants(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    participants = TontineService(db).participants(context.tontine.id)
    return success([out.participant(p) for p in participants])


@router.put(
    "/tontines/{tontine_id}/participants/order", summary="Ordre de passage manuel"
)
def set_order(
    db: DbSession, context: TontineCtx, payload: ParticipantOrder
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.edit")
    participants = TontineService(db).set_manual_order(
        context.tontine, payload.participant_ids, context.membership
    )
    return success([out.participant(p) for p in participants])


@router.get("/tontines/{tontine_id}/cycles", summary="Cycles de la tontine")
def list_cycles(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    return success(_cycles_payload(db, context.tontine.id))


@router.get("/tontines/{tontine_id}/cycles/current", summary="Cycle en cours")
def read_current_cycle(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    service = TontineService(db)
    current = service.current_cycle(context.tontine.id)
    if current is None:
        # Corps vide : le client interprète « aucun cycle en cours ».
        return success(None)
    return success(_cycle_payload(db, current))


@router.get(
    "/tontines/{tontine_id}/cycles/{cycle_id}", summary="Détail d'un cycle"
)
def read_tontine_cycle(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    cycle = TontineService(db).cycle(cycle_id, context.organization_id)
    return success(_cycle_payload(db, cycle))


@router.get("/cycles/{cycle_id}", summary="Détail d'un cycle")
def read_cycle(db: DbSession, context: CycleCtx, cycle_id: uuid.UUID) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "tontine.view")
    cycle = TontineService(db).cycle(cycle_id, context.organization_id)
    return success(_cycle_payload(db, cycle))


# --- Interne ----------------------------------------------------------------


def _update(db: DbSession, context: TontineCtx, payload: TontineUpdate):
    PermissionService(db).require(context.membership, "tontine.edit")
    service = TontineService(db)
    data = payload.model_dump(exclude_unset=True, exclude_none=True)
    new_status = data.pop("status", None)

    tontine = context.tontine
    if data:
        tontine = service.update(tontine, data, context.membership)
    if new_status is not None:
        tontine = service.change_status(
            tontine, TontineStatus(getattr(new_status, "value", new_status)),
            context.membership,
        )
    return success(out.tontine(tontine))


def _cycle_payload(db: DbSession, cycle) -> dict[str, Any]:
    payouts = PayoutService(db)
    beneficiary = payouts.of_cycle(cycle.id)
    payout = payouts.payout_of_cycle(cycle.id)
    return out.cycle(cycle, beneficiary_model=beneficiary, payout_model=payout)


def _cycles_payload(db: DbSession, tontine_id: uuid.UUID) -> list[dict[str, Any]]:
    service = TontineService(db)
    payouts = PayoutService(db)
    beneficiaries = {b.cycle_id: b for b in payouts.for_tontine(tontine_id)}
    payout_by_cycle = {
        p.beneficiary.cycle_id: p for p in payouts.payouts_of_tontine(tontine_id)
    }
    return [
        out.cycle(
            cycle,
            beneficiary_model=beneficiaries.get(cycle.id),
            payout_model=payout_by_cycle.get(cycle.id),
        )
        for cycle in service.cycles(tontine_id)
    ]


def _summary(db: DbSession, service: TontineService, tontine) -> dict[str, Any]:
    participants = service.participants(tontine.id)
    cycles = service.cycles(tontine.id)
    current = service.current_cycle(tontine.id)
    names = service.beneficiary_names(tontine.id)

    completed = [c for c in cycles if c.status in _COMPLETED_CYCLES]
    previous_name = None
    if current is not None:
        earlier = [
            c
            for c in cycles
            if c.sequence_number < current.sequence_number and c.id in names
        ]
        if earlier:
            previous_name = names[earlier[-1].id]

    return out.tontine_summary(
        tontine,
        participant_count=len([p for p in participants if p.is_active]),
        completed_cycles=len(completed),
        total_cycles=len(cycles),
        current_cycle=current,
        collected_current=current.collected_amount if current else Decimal("0"),
        expected_current=current.expected_amount if current else Decimal("0"),
        current_beneficiary_name=names.get(current.id) if current else None,
        previous_beneficiary_name=previous_name,
        current_cycle_payload=_cycle_payload(db, current) if current else None,
    )
