"""Cotisations associatives, exceptionnelles et volontaires.

Une cotisation est un **engagement** ; un paiement est une **transaction** ;
une caisse détient les **fonds**. Les trois ne se confondent jamais, et les
agrégats renvoyés ici les distinguent explicitement : attendu, encaissé, reste
à encaisser, en retard.

Les cotisations de tontine ne passent pas par ce module — elles vivent dans
`/contributions` et alimentent la cagnotte d'un cycle.
"""

from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import (
    CampaignCtx,
    CurrentUser,
    DbSession,
    EntryCtx,
    OrgContext,
    get_organization_context,
)
from app.core.errors import ConflictError, NotFoundError
from app.core.responses import success
from app.models.campaign import CampaignPayment
from app.models.enums import CampaignStatus, ContributionType
from app.schemas.campaign import (
    CampaignCreate,
    CampaignExemption,
    CampaignPaymentCancel,
    CampaignPaymentCreate,
    CampaignUpdate,
)
from app.services.campaign_service import CampaignService
from app.services.permission_service import PermissionService

router = APIRouter(tags=["cotisations"])


@router.get(
    "/organizations/{organization_id}/contribution-campaigns",
    summary="Cotisations de l'association",
)
def list_campaigns(
    db: DbSession,
    context: OrgContext,
    contribution_type: Annotated[
        ContributionType | None, Query(alias="type")
    ] = None,
    campaign_status: Annotated[
        CampaignStatus | None, Query(alias="status")
    ] = None,
    cashbox_id: Annotated[uuid.UUID | None, Query(alias="cashboxId")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    service = CampaignService(db)
    # Les retards se constatent à la lecture : pas d'ordonnanceur dont
    # dépendrait l'exactitude de ce que l'écran affiche.
    service.refresh_late(context.organization_id)
    db.commit()

    campaigns, total = service.list_for(
        context.organization_id,
        contribution_type=contribution_type,
        status=campaign_status,
        cashbox_id=cashbox_id,
        limit=limit,
        offset=offset,
    )
    return success(
        [service.serialize(campaign) for campaign in campaigns],
        meta={"total": total, "limit": limit, "offset": offset},
    )


@router.post(
    "/organizations/{organization_id}/contribution-campaigns",
    status_code=status.HTTP_201_CREATED,
    summary="Créer une cotisation",
)
def create_campaign(
    db: DbSession, context: OrgContext, payload: CampaignCreate
) -> dict[str, Any]:
    """Crée la cotisation **et** le suivi individuel des membres concernés."""
    PermissionService(db).require(context.membership, "contribution.create")
    service = CampaignService(db)
    campaign = service.create(
        organization_id=context.organization_id,
        actor=context.membership,
        title=payload.title,
        description=payload.description,
        contribution_type=payload.contribution_type,
        amount=payload.amount,
        amount_mode=payload.amount_mode,
        currency=payload.currency,
        start_date=payload.start_date,
        due_date=payload.due_date,
        member_ids=payload.member_ids,
        cashbox_id=payload.cashbox_id,
        tontine_id=payload.tontine_id,
        mandatory=payload.mandatory,
        penalty_enabled=payload.penalty_enabled,
        penalty_amount=payload.penalty_amount,
    )
    db.commit()
    db.refresh(campaign)
    return success(service.serialize(campaign))


@router.get(
    "/contribution-campaigns/{campaign_id}", summary="Détail d'une cotisation"
)
def read_campaign(
    db: DbSession, context: CampaignCtx, campaign_id: uuid.UUID
) -> dict[str, Any]:
    """Agrégats de la campagne et suivi de chaque membre concerné."""
    PermissionService(db).require(context.membership, "contribution.view")
    service = CampaignService(db)
    campaign = service.get(context.organization_id, campaign_id)
    service.refresh_late(context.organization_id)
    db.commit()

    payload = service.serialize(campaign)
    payload["entries"] = [
        CampaignService.serialize_entry(entry)
        for entry in service.entries_of(campaign.id)
    ]
    return success(payload)


@router.patch(
    "/contribution-campaigns/{campaign_id}", summary="Modifier une cotisation"
)
def update_campaign(
    db: DbSession,
    context: CampaignCtx,
    campaign_id: uuid.UUID,
    payload: CampaignUpdate,
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.update")
    service = CampaignService(db)
    campaign = service.get(context.organization_id, campaign_id)

    if payload.status is CampaignStatus.CLOSED:
        service.close(campaign, actor=context.membership)
    elif payload.status is not None:
        campaign.status = payload.status.value
    if payload.title is not None:
        campaign.title = payload.title
    if payload.description is not None:
        campaign.description = payload.description
    if payload.due_date is not None:
        campaign.due_date = payload.due_date
        # L'échéance vit sur la campagne **et** sur chaque ligne : la reporter
        # sur la campagne seule laisserait les membres en retard sans raison.
        for entry in service.entries_of(campaign.id):
            entry.due_date = payload.due_date
    if payload.mandatory is not None:
        campaign.mandatory = payload.mandatory
    if payload.penalty_enabled is not None:
        campaign.penalty_enabled = payload.penalty_enabled
    if payload.penalty_amount is not None:
        campaign.penalty_amount = payload.penalty_amount

    db.commit()
    db.refresh(campaign)
    return success(service.serialize(campaign))


@router.get(
    "/contribution-campaigns/{campaign_id}/entries",
    summary="Suivi individuel d'une cotisation",
)
def list_entries(
    db: DbSession, context: CampaignCtx, campaign_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    service = CampaignService(db)
    campaign = service.get(context.organization_id, campaign_id)
    entries = service.entries_of(campaign.id)
    return success(
        [CampaignService.serialize_entry(entry) for entry in entries],
        meta={"total": len(entries), "summary": service.summary(campaign)},
    )


@router.get(
    "/contribution-entries/{entry_id}", summary="Fiche d'un membre pour une cotisation"
)
def read_entry(
    db: DbSession, context: EntryCtx, entry_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "contribution.view")
    entry = CampaignService(db).entry(context.organization_id, entry_id)
    return success(CampaignService.serialize_entry(entry, with_payments=True))


@router.post(
    "/contribution-entries/{entry_id}/payments",
    status_code=status.HTTP_201_CREATED,
    summary="Enregistrer un règlement",
)
def record_payment(
    db: DbSession,
    context: EntryCtx,
    entry_id: uuid.UUID,
    payload: CampaignPaymentCreate,
) -> dict[str, Any]:
    """Une saisie, sept effets — dans une seule transaction.

    Règlement enregistré, suivi du membre à jour, reste et statut recalculés,
    écriture de caisse créée, solde modifié, audit tracé, notification envoyée.
    """
    service = PermissionService(db)
    # Deux codes acceptés : l'historique et le plus fin. Un rôle sur mesure
    # peut ainsi n'accorder que `payment.create` sans porter tout le lot.
    service.require_any(
        context.membership, "payment.create", "contribution.record"
    )
    campaigns = CampaignService(db)
    entry = campaigns.entry(context.organization_id, entry_id)

    payment = campaigns.record_payment(
        entry=entry,
        actor=context.membership,
        amount=payload.amount,
        payment_method=payload.payment_method,
        reference=payload.reference,
        comment=payload.comment,
        proof_url=payload.proof_url,
        paid_at=payload.paid_at,
    )
    db.commit()
    db.refresh(entry)
    return success(
        {
            "payment": CampaignService.serialize_payment(payment),
            "entry": CampaignService.serialize_entry(entry),
        }
    )


@router.post(
    "/contribution-entries/{entry_id}/exempt", summary="Exempter un membre"
)
def exempt_member(
    db: DbSession,
    context: EntryCtx,
    entry_id: uuid.UUID,
    payload: CampaignExemption,
) -> dict[str, Any]:
    """La ligne sort de l'attendu — le taux de recouvrement reste sincère."""
    PermissionService(db).require(context.membership, "contribution.exempt")
    service = CampaignService(db)
    entry = service.exempt(
        service.entry(context.organization_id, entry_id),
        actor=context.membership,
        reason=payload.reason,
    )
    db.commit()
    db.refresh(entry)
    return success(CampaignService.serialize_entry(entry))


@router.post(
    "/contribution-payments/{payment_id}/cancel", summary="Annuler un règlement"
)
def cancel_payment(
    db: DbSession,
    user: CurrentUser,
    payment_id: uuid.UUID,
    payload: CampaignPaymentCancel,
) -> dict[str, Any]:
    """Annule le règlement **et** contrepasse son écriture de caisse."""
    payment = db.get(CampaignPayment, payment_id)
    if payment is None:
        raise NotFoundError("Règlement introuvable.", code="payment_not_found")
    context = get_organization_context(db, user, payment.organization_id)
    PermissionService(db).require(context.membership, "payment.cancel")

    service = CampaignService(db)
    service.cancel_payment(payment, actor=context.membership, reason=payload.reason)
    db.commit()
    db.refresh(payment)
    return success(
        {
            "payment": CampaignService.serialize_payment(payment),
            "entry": CampaignService.serialize_entry(payment.entry),
        }
    )


@router.get("/organizations/{organization_id}/unpaid", summary="Impayés")
def list_unpaid(
    db: DbSession,
    context: OrgContext,
    limit: Annotated[int, Query(ge=1, le=200)] = 100,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> dict[str, Any]:
    """Membre, cotisation, dû, payé, reste et jours de retard."""
    PermissionService(db).require(context.membership, "contribution.view")
    service = CampaignService(db)
    service.refresh_late(context.organization_id)
    db.commit()

    entries, total = service.unpaid(
        context.organization_id, limit=limit, offset=offset
    )
    return success(
        [
            {
                **CampaignService.serialize_entry(entry),
                "campaignTitle": entry.campaign.title,
                "contributionType": entry.campaign.contribution_type,
            }
            for entry in entries
        ],
        meta={"total": total, "limit": limit, "offset": offset},
    )
