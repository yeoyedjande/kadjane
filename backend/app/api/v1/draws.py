"""Tirage : le serveur décide, l'application affiche."""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, status

from app.core.deps import CurrentUser, CycleCtx, DbSession, TontineCtx
from app.core.errors import NotFoundError, ValidationError
from app.core.responses import success
from app.models.draw import DrawSession
from app.schemas import serializers as out
from app.schemas.tontine import DrawClose, DrawRequest
from app.services import permission_service
from app.services.draw_service import DrawService
from app.services.tontine_service import TontineService

router = APIRouter(tags=["tirages"])


# --- Éligibilité -------------------------------------------------------------


@router.get(
    "/tontines/{tontine_id}/cycles/{cycle_id}/draw-eligibility",
    summary="Conditions du tirage",
)
def draw_eligibility(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    return _eligibility(db, context, cycle_id)


@router.get(
    "/tontines/{tontine_id}/cycles/{cycle_id}/draw/eligibility",
    summary="Conditions du tirage (alias)",
)
def draw_eligibility_alias(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    return _eligibility(db, context, cycle_id)


# --- Exécution ---------------------------------------------------------------


@router.post(
    "/tontines/{tontine_id}/draws",
    status_code=status.HTTP_201_CREATED,
    summary="Lancer le tirage d'un cycle",
)
def run_draw(
    db: DbSession, context: TontineCtx, payload: DrawRequest
) -> dict[str, Any]:
    if payload.cycle_id is None:
        raise ValidationError("`cycleId` est obligatoire.", code="cycle_required")
    return _run(db, context, payload.cycle_id, payload)


@router.post(
    "/tontines/{tontine_id}/cycles/{cycle_id}/draw",
    status_code=status.HTTP_201_CREATED,
    summary="Lancer le tirage d'un cycle (alias)",
)
def run_cycle_draw(
    db: DbSession,
    context: TontineCtx,
    cycle_id: uuid.UUID,
    payload: DrawRequest | None = None,
) -> dict[str, Any]:
    return _run(db, context, cycle_id, payload or DrawRequest())


@router.post(
    "/tontines/{tontine_id}/draws/order",
    status_code=status.HTTP_201_CREATED,
    summary="Tirer l'ordre de passage complet",
)
def run_order_draw(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "draw.run")
    session = DrawService(db).generate_full_order(
        tontine=context.tontine, actor=context.membership
    )
    return success(out.draw_session(session))


# --- Historique --------------------------------------------------------------


@router.get("/tontines/{tontine_id}/draws", summary="Historique des tirages")
def draw_history(db: DbSession, context: TontineCtx) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "draw.view")
    sessions = DrawService(db).history(context.tontine.id)
    return success([out.draw_session(session) for session in sessions])


@router.get("/draws/{draw_id}", summary="Détail d'un tirage")
def read_draw(db: DbSession, user: CurrentUser, draw_id: uuid.UUID) -> dict[str, Any]:
    session, _ = _guarded_draw(db, user, draw_id, "draw.view")
    return success(out.draw_session(session))


@router.get("/cycles/{cycle_id}/draw", summary="Tirage d'un cycle")
def read_cycle_draw(
    db: DbSession, context: CycleCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "draw.view")
    session = DrawService(db).completed_draw_of(cycle_id)
    return success(out.draw_session(session) if session else None)


@router.post("/draws/{draw_id}/cancel", summary="Annuler un tirage programmé")
def cancel_draw(
    db: DbSession, user: CurrentUser, draw_id: uuid.UUID, payload: DrawClose
) -> dict[str, Any]:
    session, context = _guarded_draw(db, user, draw_id, "draw.run")
    cancelled = DrawService(db).cancel(session, payload.reason, context.membership)
    return success(out.draw_session(cancelled))


@router.post("/draws/{draw_id}/invalidate", summary="Invalider un tirage validé")
def invalidate_draw(
    db: DbSession, user: CurrentUser, draw_id: uuid.UUID, payload: DrawClose
) -> dict[str, Any]:
    session, context = _guarded_draw(db, user, draw_id, "draw.invalidate")
    invalidated = DrawService(db).invalidate(
        session, payload.reason, context.membership
    )
    return success(out.draw_session(invalidated))


# --- Interne ----------------------------------------------------------------


def _eligibility(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "draw.view")
    cycle = TontineService(db).cycle(cycle_id, context.organization_id)
    evaluation = DrawService(db).evaluate(context.tontine, cycle)
    return success(out.eligibility(evaluation, tontine_model=context.tontine))


def _run(
    db: DbSession, context: TontineCtx, cycle_id: uuid.UUID, payload: DrawRequest
) -> dict[str, Any]:
    cycle = TontineService(db).cycle(cycle_id, context.organization_id)
    session = DrawService(db).run(
        tontine=context.tontine,
        cycle=cycle,
        actor=context.membership,
        override=payload.override,
        override_reason=payload.override_reason,
    )
    payload_out = out.draw_session(session)
    # Raccourcis attendus par le cahier des charges, en plus du contrat mobile.
    winner = session.winner
    payload_out["draw_id"] = payload_out["id"]
    payload_out["winner"] = (
        {
            "participant_id": str(winner.id),
            "member_id": str(winner.organization_member_id),
            "name": winner.display_name,
        }
        if winner
        else None
    )
    payload_out["payout_amount"] = out.money(cycle.expected_amount)
    payload_out["period"] = cycle.period_label
    return success(payload_out)


def _guarded_draw(
    db: DbSession, user: CurrentUser, draw_id: uuid.UUID, permission: str
):
    from app.core.deps import get_organization_context

    session = db.get(DrawSession, draw_id)
    if session is None:
        raise NotFoundError("Tirage introuvable.", code="draw_not_found")
    context = get_organization_context(db, user, session.organization_id)
    permission_service.require(context.membership.role_enum, permission)
    return session, context
