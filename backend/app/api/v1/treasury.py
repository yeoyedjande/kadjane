from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import DbSession, OrgContext
from app.core.responses import success
from app.schemas.treasury import TransactionCreate
from app.services import permission_service
from app.services.treasury_service import TreasuryService

router = APIRouter(tags=["trésorerie"])


@router.get("/organizations/{organization_id}/treasury", summary="Trésorerie")
def read_treasury(
    db: DbSession,
    context: OrgContext,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> dict[str, Any]:
    """Solde, entrées, sorties et journal unifié des mouvements."""
    permission_service.require(context.membership.role_enum, "treasury.view")
    return success(TreasuryService(db).snapshot(context.organization_id, limit=limit))


@router.post(
    "/organizations/{organization_id}/transactions",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un mouvement de caisse",
)
def record_transaction(
    db: DbSession, context: OrgContext, payload: TransactionCreate
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "treasury.manage")
    service = TreasuryService(db)
    transaction = service.record_transaction(
        organization_id=context.organization_id,
        actor=context.membership,
        type_=payload.type,
        category=payload.category,
        amount=payload.amount,
        date=payload.date,
        description=payload.description,
        tontine_id=payload.tontine_id,
        proof_url=payload.proof_url,
    )
    return success(service.serialize(transaction))


@router.get("/organizations/{organization_id}/reports", summary="Rapports")
def read_reports(db: DbSession, context: OrgContext) -> dict[str, Any]:
    """Attendu, collecté et distribué, globalement et par tontine."""
    permission_service.require(context.membership.role_enum, "report.view")
    return success(TreasuryService(db).report(context.organization_id))
