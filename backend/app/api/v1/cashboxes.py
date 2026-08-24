"""Caisses et mouvements de caisse.

Chaque écriture est nominative et datée, et aucune ne disparaît : annuler
change un statut, jamais une ligne. Le solde n'est pas une colonne mais la
somme du journal — c'est lui qui fait foi.
"""

from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status
from sqlalchemy import func, select

from app.core.deps import (
    CashboxCtx,
    CurrentUser,
    DbSession,
    OrgContext,
    get_organization_context,
)
from app.core.errors import NotFoundError
from app.core.responses import success
from app.models.enums import CashTransactionStatus
from app.models.treasury import CashTransaction
from app.schemas.treasury import (
    CashboxCreate,
    CashboxUpdate,
    CashTransactionCancel,
    CashTransactionCreate,
)
from app.services.cashbox_service import CashboxService
from app.services.permission_service import PermissionService

router = APIRouter(tags=["caisses"])


@router.get("/organizations/{organization_id}/cashboxes", summary="Caisses")
def list_cashboxes(db: DbSession, context: OrgContext) -> dict[str, Any]:
    """Caisses de l'association, soldes calculés."""
    PermissionService(db).require(context.membership, "cashbox.view")
    service = CashboxService(db)
    boxes = service.list_for(context.organization_id)
    return success(
        [service.serialize(cashbox) for cashbox in boxes],
        meta={"total": len(boxes)},
    )


@router.post(
    "/organizations/{organization_id}/cashboxes",
    status_code=status.HTTP_201_CREATED,
    summary="Ouvrir une caisse",
)
def create_cashbox(
    db: DbSession, context: OrgContext, payload: CashboxCreate
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "cashbox.create")
    service = CashboxService(db)
    cashbox = service.create(
        organization_id=context.organization_id,
        actor=context.membership,
        name=payload.name,
        description=payload.description,
        currency=payload.currency,
        opening_balance=payload.opening_balance,
        is_default=payload.is_default,
    )
    db.commit()
    db.refresh(cashbox)
    return success(service.serialize(cashbox))


@router.get("/cashboxes/{cashbox_id}", summary="Détail d'une caisse")
def read_cashbox(
    db: DbSession, context: CashboxCtx, cashbox_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "cashbox.view")
    service = CashboxService(db)
    return success(service.serialize(service.get(context.organization_id, cashbox_id)))


@router.patch("/cashboxes/{cashbox_id}", summary="Modifier une caisse")
def update_cashbox(
    db: DbSession,
    context: CashboxCtx,
    cashbox_id: uuid.UUID,
    payload: CashboxUpdate,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "cashbox.update")
    service = CashboxService(db)
    cashbox = service.update(
        service.get(context.organization_id, cashbox_id),
        actor=context.membership,
        name=payload.name,
        description=payload.description,
        is_default=payload.is_default,
    )
    db.commit()
    db.refresh(cashbox)
    return success(service.serialize(cashbox))


@router.post("/cashboxes/{cashbox_id}/close", summary="Fermer une caisse")
def close_cashbox(
    db: DbSession, context: CashboxCtx, cashbox_id: uuid.UUID
) -> dict[str, Any]:
    """Le solde résiduel reste lisible : fermer ne fait pas disparaître l'argent."""
    PermissionService(db).require(context.membership, "cashbox.close")
    service = CashboxService(db)
    cashbox = service.close(
        service.get(context.organization_id, cashbox_id), actor=context.membership
    )
    db.commit()
    db.refresh(cashbox)
    return success(service.serialize(cashbox))


@router.get(
    "/cashboxes/{cashbox_id}/transactions", summary="Journal d'une caisse"
)
def list_transactions(
    db: DbSession,
    context: CashboxCtx,
    cashbox_id: uuid.UUID,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
    include_cancelled: Annotated[
        bool, Query(alias="includeCancelled")
    ] = True,
) -> dict[str, Any]:
    """Mouvements de la caisse, du plus récent au plus ancien.

    Les écritures annulées sont visibles par défaut : elles ne comptent pas
    dans le solde, mais les masquer rendrait le journal incompréhensible pour
    qui cherche à comprendre un écart.
    """
    PermissionService(db).require(context.membership, "cashbox.view")
    service = CashboxService(db)
    cashbox = service.get(context.organization_id, cashbox_id)

    statement = select(CashTransaction).where(
        CashTransaction.cashbox_id == cashbox.id
    )
    if not include_cancelled:
        statement = statement.where(
            CashTransaction.status == CashTransactionStatus.CONFIRMED.value
        )
    total = int(
        db.scalar(select(func.count()).select_from(statement.subquery())) or 0
    )
    rows = db.scalars(
        statement.order_by(CashTransaction.date.desc()).offset(offset).limit(limit)
    )
    return success(
        [CashboxService.serialize_transaction(row) for row in rows],
        meta={"total": total, "limit": limit, "offset": offset},
    )


@router.post(
    "/cashboxes/{cashbox_id}/transactions",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un mouvement",
)
def record_transaction(
    db: DbSession,
    context: CashboxCtx,
    cashbox_id: uuid.UUID,
    payload: CashTransactionCreate,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "cash_transaction.create")
    service = CashboxService(db)
    transaction = service.record(
        cashbox=service.get(context.organization_id, cashbox_id),
        actor=context.membership,
        type_=payload.type,
        category=payload.category,
        amount=payload.amount,
        date=payload.date,
        description=payload.description,
        reference=payload.reference,
        proof_url=payload.proof_url,
        tontine_id=payload.tontine_id,
    )
    db.commit()
    db.refresh(transaction)
    return success(CashboxService.serialize_transaction(transaction))


@router.post(
    "/cash-transactions/{transaction_id}/cancel", summary="Annuler un mouvement"
)
def cancel_transaction(
    db: DbSession,
    user: CurrentUser,
    transaction_id: uuid.UUID,
    payload: CashTransactionCancel,
) -> dict[str, Any]:
    """L'écriture sort du solde, pas du journal."""
    transaction = db.get(CashTransaction, transaction_id)
    if transaction is None:
        raise NotFoundError("Mouvement introuvable.", code="transaction_not_found")
    context = get_organization_context(db, user, transaction.organization_id)
    PermissionService(db).require(context.membership, "cash_transaction.cancel")

    CashboxService(db).cancel(
        transaction,
        actor=context.membership,
        reason=payload.reason,
        reversed_=payload.reversed,
    )
    db.commit()
    db.refresh(transaction)
    return success(CashboxService.serialize_transaction(transaction))
