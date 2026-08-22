"""Cotisations de caisse : les sommes dues à l'association, hors tontine.

Les échéances sont engendrées à la lecture (`ensure_entries`) : consulter une
cotisation suffit à faire apparaître les périodes écoulées, sans tâche
planifiée.
"""

from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession, OrgContext
from app.core.errors import NotFoundError, PermissionDeniedError
from app.core.responses import success
from app.repositories.member_repository import MemberRepository
from app.schemas.base import dump, dump_all
from app.schemas.dues import (
    DuesEntryRead,
    DuesPaymentCancel,
    DuesPaymentCreate,
    DuesPaymentRead,
    DuesPlanCreate,
    DuesPlanRead,
    DuesPlanUpdate,
)
from app.services import permission_service
from app.services.dues_service import DuesService

router = APIRouter(tags=["cotisations de caisse"])


def _entry_payload(entry) -> dict[str, Any]:
    """Sérialise une échéance en exposant le reste à payer, déjà calculé."""
    body = dump(DuesEntryRead.model_validate(entry, from_attributes=True))
    body["remainingAmount"] = str(entry.remaining_amount)
    return body


@router.get(
    "/organizations/{organization_id}/dues-plans",
    summary="Cotisations de caisse de l'organisation",
)
def list_plans(db: DbSession, context: OrgContext) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "dues.view")
    service = DuesService(db)
    plans = service.plans(context.organization_id)

    items = []
    for plan in plans:
        # Lecture = mise à jour : les périodes écoulées apparaissent d'elles-mêmes.
        service.ensure_entries(plan)
        body = dump(DuesPlanRead.model_validate(plan, from_attributes=True))
        body["summary"] = {
            key: str(value) if hasattr(value, "quantize") else value
            for key, value in service.plan_summary(plan).items()
        }
        items.append(body)
    return success(items)


@router.post(
    "/organizations/{organization_id}/dues-plans",
    status_code=status.HTTP_201_CREATED,
    summary="Créer une cotisation de caisse",
)
def create_plan(
    db: DbSession, context: OrgContext, payload: DuesPlanCreate
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "dues.manage")
    plan = DuesService(db).create_plan(
        context.organization_id,
        name=payload.name,
        amount=payload.amount,
        actor=context.membership,
        frequency=payload.frequency,
        due_day=payload.due_day,
        custom_period_days=payload.custom_period_days,
        start_date=payload.start_date,
        description=payload.description,
        currency=payload.currency,
    )
    return success(dump(DuesPlanRead.model_validate(plan, from_attributes=True)))


@router.patch(
    "/organizations/{organization_id}/dues-plans/{plan_id}",
    summary="Mettre à jour une cotisation de caisse",
)
def update_plan(
    db: DbSession, context: OrgContext, plan_id: uuid.UUID, payload: DuesPlanUpdate
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "dues.manage")
    service = DuesService(db)
    plan = service.get_plan(plan_id, context.organization_id)
    plan = service.update_plan(
        plan,
        context.membership,
        name=payload.name,
        amount=payload.amount,
        description=payload.description,
        due_day=payload.due_day,
        status=payload.status,
    )
    return success(dump(DuesPlanRead.model_validate(plan, from_attributes=True)))


@router.get(
    "/organizations/{organization_id}/dues-plans/{plan_id}/entries",
    summary="Échéances d'une cotisation",
)
def list_entries(
    db: DbSession,
    context: OrgContext,
    plan_id: uuid.UUID,
    period: Annotated[int | None, Query(ge=1, description="Numéro de période")] = None,
    member_id: Annotated[uuid.UUID | None, Query(alias="memberId")] = None,
) -> dict[str, Any]:
    permission_service.require(context.membership.role_enum, "dues.view")
    service = DuesService(db)
    plan = service.get_plan(plan_id, context.organization_id)
    service.ensure_entries(plan)
    entries = service.entries(plan, sequence_number=period, member_id=member_id)
    return success([_entry_payload(entry) for entry in entries])


@router.post(
    "/dues-entries/{entry_id}/payments",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un règlement de cotisation",
)
def record_payment(
    db: DbSession, user: CurrentUser, entry_id: uuid.UUID, payload: DuesPaymentCreate
) -> dict[str, Any]:
    """Le trésorier encaisse : c'est lui qui détient l'argent de la caisse."""
    service = DuesService(db)
    entry, membership = _guarded_entry(db, user, entry_id, "dues.record")
    payment = service.record_payment(
        entry=entry,
        amount=payload.amount,
        method=payload.payment_method,
        actor=membership,
        reference=payload.reference,
        comment=payload.comment,
        proof_url=payload.proof_url,
        paid_at=payload.paid_at,
    )
    body = dump(DuesPaymentRead.model_validate(payment, from_attributes=True))
    body["entry"] = _entry_payload(entry)
    return success(body)


@router.post(
    "/dues-payments/{payment_id}/cancel",
    summary="Annuler un règlement de cotisation",
)
def cancel_payment(
    db: DbSession, user: CurrentUser, payment_id: uuid.UUID, payload: DuesPaymentCancel
) -> dict[str, Any]:
    from app.models.dues import DuesPayment

    payment = db.get(DuesPayment, payment_id)
    if payment is None:
        raise NotFoundError("Règlement introuvable.", code="dues_payment_not_found")
    membership = _membership_or_404(db, user, payment.organization_id)
    permission_service.require(membership.role_enum, "dues.record")

    payment = DuesService(db).cancel_payment(
        payment, membership, reason=payload.reason
    )
    return success(dump(DuesPaymentRead.model_validate(payment, from_attributes=True)))


@router.get(
    "/organizations/{organization_id}/dues-outstanding",
    summary="Échéances de caisse non soldées",
)
def list_outstanding(
    db: DbSession,
    context: OrgContext,
    member_id: Annotated[uuid.UUID | None, Query(alias="memberId")] = None,
) -> dict[str, Any]:
    """Ce que le trésorier réclame — alimente le centre de relance."""
    permission_service.require(context.membership.role_enum, "dues.view")
    service = DuesService(db)
    for plan in service.plans(context.organization_id):
        service.ensure_entries(plan)

    entries = service.outstanding(context.organization_id, member_id=member_id)
    return success([_entry_payload(entry) for entry in entries])


@router.get("/me/dues", summary="Mes cotisations de caisse à régler")
def my_dues(db: DbSession, user: CurrentUser, organization_id: Annotated[uuid.UUID, Query(alias="organizationId")]) -> dict[str, Any]:
    """Vue du membre : ce qu'il doit lui-même, sans droit particulier."""
    membership = _membership_or_404(db, user, organization_id)
    service = DuesService(db)
    for plan in service.plans(organization_id):
        service.ensure_entries(plan)

    entries = service.outstanding(organization_id, member_id=membership.id)
    return success([_entry_payload(entry) for entry in entries])


# --- Interne ----------------------------------------------------------------


def _membership_or_404(db, user, organization_id: uuid.UUID):
    """Appartenance de l'appelant, ou 404.

    Volontairement 404 et non 403 : ne pas révéler l'existence d'une
    organisation à qui n'en fait pas partie.
    """
    membership = MemberRepository(db).membership(organization_id, user.id)
    if membership is None:
        raise NotFoundError("Organisation introuvable.", code="organization_not_found")
    return membership


def _guarded_entry(db, user, entry_id: uuid.UUID, permission: str):
    """Charge une échéance et vérifie les droits de l'appelant sur celle-ci."""
    from app.models.dues import DuesEntry

    entry = db.get(DuesEntry, entry_id)
    if entry is None:
        raise NotFoundError("Échéance introuvable.", code="dues_entry_not_found")
    membership = _membership_or_404(db, user, entry.organization_id)
    if not permission_service.can(membership.role_enum, permission):
        raise PermissionDeniedError(
            "Votre rôle ne permet pas cette action.", code="permission_denied"
        )
    return entry, membership
