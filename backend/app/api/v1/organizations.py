from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession, OrgContext
from app.core.errors import NotFoundError
from app.core.responses import success
from app.models.enums import OrgRole
from app.repositories.member_repository import MemberRepository
from app.schemas.base import dump, dump_all
from app.schemas.member import MemberRead
from app.schemas.organization import (
    OrganizationCreate,
    OrganizationRead,
    OrganizationUpdate,
)
from app.services.permission_service import PermissionService
from app.services.dashboard_service import DashboardService
from app.services.organization_service import OrganizationService

router = APIRouter(prefix="/organizations", tags=["organisations"])


@router.get("", summary="Organisations de l'utilisateur connecté")
def list_organizations(db: DbSession, user: CurrentUser) -> dict[str, Any]:
    """Ne renvoie **que** les organisations dont l'appelant est membre.

    Le paramètre `userId` éventuellement envoyé par le client est ignoré :
    l'identité vient du jeton, jamais de la requête.
    """
    organizations = OrganizationService(db).list_for_user(user.id)
    return success(
        dump_all([OrganizationRead.model_validate(o) for o in organizations]),
        meta={"total": len(organizations)},
    )


@router.post("", status_code=status.HTTP_201_CREATED, summary="Créer une organisation")
def create_organization(
    db: DbSession, user: CurrentUser, payload: OrganizationCreate
) -> dict[str, Any]:
    organization = OrganizationService(db).create(payload, user)
    return success(dump(OrganizationRead.model_validate(organization)))


@router.get("/{organization_id}", summary="Détail d'une organisation")
def read_organization(context: OrgContext) -> dict[str, Any]:
    return success(dump(OrganizationRead.model_validate(context.organization)))


@router.put("/{organization_id}", summary="Mettre à jour une organisation")
def replace_organization(
    db: DbSession, context: OrgContext, payload: OrganizationUpdate
) -> dict[str, Any]:
    return _update(db, context, payload)


@router.patch("/{organization_id}", summary="Mise à jour partielle")
def patch_organization(
    db: DbSession, context: OrgContext, payload: OrganizationUpdate
) -> dict[str, Any]:
    return _update(db, context, payload)


@router.get("/{organization_id}/membership", summary="Appartenance d'un utilisateur")
def read_membership(
    db: DbSession,
    context: OrgContext,
    user_id: Annotated[uuid.UUID | None, Query(alias="userId")] = None,
) -> dict[str, Any]:
    """Par défaut l'appartenance de l'appelant.

    Demander celle d'un autre utilisateur suppose le droit `member.view`,
    et reste borné à l'organisation courante.
    """
    if user_id is None or user_id == context.user.id:
        return success(dump(MemberRead.model_validate(context.membership)))

    PermissionService(db).require(context.membership, "member.view")
    membership = MemberRepository(db).membership(context.organization_id, user_id)
    if membership is None:
        raise NotFoundError("Appartenance introuvable.", code="membership_not_found")
    return success(dump(MemberRead.model_validate(membership)))


@router.get("/{organization_id}/officers", summary="Responsables de l'organisation")
def read_officers(db: DbSession, context: OrgContext) -> dict[str, Any]:
    officers = MemberRepository(db).officers(context.organization_id)
    return success(dump_all([MemberRead.model_validate(m) for m in officers]))


@router.get("/{organization_id}/dashboard", summary="Tableau de bord")
def read_dashboard(
    db: DbSession,
    context: OrgContext,
    member_id: Annotated[uuid.UUID | None, Query(alias="memberId")] = None,
) -> dict[str, Any]:
    snapshot = DashboardService(db).load(
        context.organization, member_id or context.membership.id
    )
    return success(snapshot)


# --- Interne ----------------------------------------------------------------


def _update(db: DbSession, context: OrgContext, payload: OrganizationUpdate):
    PermissionService(db).require(context.membership, "organization.edit")
    organization = OrganizationService(db).update(context.organization, payload)
    return success(dump(OrganizationRead.model_validate(organization)))
