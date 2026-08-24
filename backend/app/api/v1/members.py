from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status

from app.core.deps import CurrentUser, DbSession, OrgContext, get_organization_context
from app.core.errors import NotFoundError
from app.core.responses import success
from app.models.enums import MemberStatus, OrgRole
from app.repositories.member_repository import MemberRepository
from app.schemas.base import dump, dump_all
from app.schemas.member import MemberCreate, MemberRead, MemberStats, MemberUpdate
from app.services.permission_service import PermissionService
from app.services.member_service import MemberService

router = APIRouter(tags=["membres"])


@router.get(
    "/organizations/{organization_id}/members",
    summary="Membres d'une organisation (paginé)",
)
def list_members(
    db: DbSession,
    context: OrgContext,
    query: Annotated[str, Query(description="Recherche nom, téléphone, e-mail")] = "",
    search: Annotated[str, Query(description="Alias de `query`")] = "",
    role: Annotated[OrgRole | None, Query()] = None,
    status_filter: Annotated[MemberStatus | None, Query(alias="status")] = None,
    page: Annotated[int, Query(ge=0, description="Page, indexée à partir de 0")] = 0,
    page_size: Annotated[int, Query(alias="pageSize", ge=1, le=200)] = 20,
    page_size_snake: Annotated[int | None, Query(alias="page_size", ge=1, le=200)] = None,
) -> dict[str, Any]:
    """Liste bornée à l'organisation du contexte.

    Réponse : `data = {items, page, pageSize, hasMore, total}` — la forme
    `paged<T>` attendue par l'application ; `meta` reprend la pagination pour
    les clients qui la lisent à part.
    """
    PermissionService(db).require(context.membership, "member.view")

    size = page_size_snake or page_size
    term = query or search
    members, total = MemberService(db).search(
        context.organization_id,
        query=term,
        role=role,
        status=status_filter,
        page=page,
        page_size=size,
    )
    has_more = (page + 1) * size < total
    items = dump_all([MemberRead.model_validate(m) for m in members])
    return success(
        {
            "items": items,
            "page": page,
            "pageSize": size,
            "hasMore": has_more,
            "total": total,
        },
        meta={"page": page, "page_size": size, "total": total, "has_more": has_more},
    )


@router.post(
    "/organizations/{organization_id}/members",
    status_code=status.HTTP_201_CREATED,
    summary="Ajouter un membre",
)
def create_member(
    db: DbSession, context: OrgContext, payload: MemberCreate
) -> dict[str, Any]:
    """Ajoute un membre à l'organisation.

    Quand aucun mot de passe n'est fourni, la réponse porte en plus
    `temporaryPassword` : c'est **la seule fois** où il est lisible, la base ne
    conserve qu'une empreinte. L'administrateur le transmet au membre, qui
    pourra le changer depuis l'application.
    """
    PermissionService(db).require(context.membership, "member.create")
    member, temporary_password = MemberService(db).create(
        context.organization_id, payload, context.membership
    )
    body = dump(MemberRead.model_validate(member))
    if temporary_password is not None:
        body["temporaryPassword"] = temporary_password
    return success(body)


@router.get(
    "/organizations/{organization_id}/members/{member_id}",
    summary="Détail d'un membre",
)
def read_member_in_organization(
    db: DbSession, context: OrgContext, member_id: uuid.UUID
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "member.view")
    member = MemberService(db).get_in_organization(member_id, context.organization_id)
    return success(dump(MemberRead.model_validate(member)))


@router.patch(
    "/organizations/{organization_id}/members/{member_id}",
    summary="Mettre à jour un membre",
)
def patch_member_in_organization(
    db: DbSession, context: OrgContext, member_id: uuid.UUID, payload: MemberUpdate
) -> dict[str, Any]:
    PermissionService(db).require(context.membership, "member.edit")
    service = MemberService(db)
    member = service.get_in_organization(member_id, context.organization_id)
    return success(
        dump(MemberRead.model_validate(service.update(member, payload, context.membership)))
    )


@router.delete(
    "/organizations/{organization_id}/members/{member_id}",
    summary="Supprimer un membre",
)
def delete_member_in_organization(
    db: DbSession, context: OrgContext, member_id: uuid.UUID
) -> dict[str, Any]:
    """Retire un membre de l'organisation.

    Refusé s'il participe à une tontine : voir `MemberService.delete`.
    """
    PermissionService(db).require(context.membership, "member.delete")
    service = MemberService(db)
    member = service.get_in_organization(member_id, context.organization_id)
    service.delete(member, context.membership)
    return success({"deleted": True})


# --- Routes courtes `/members/{id}` -----------------------------------------
# L'application les utilise depuis la fiche d'un membre. L'organisation n'est
# pas dans l'URL : elle est déduite du membre visé, puis l'appartenance de
# l'appelant à cette organisation est vérifiée.


def _guarded_member(
    db: DbSession, user: CurrentUser, member_id: uuid.UUID, permission: str
):
    member = MemberRepository(db).by_id(member_id)
    if member is None:
        raise NotFoundError("Membre introuvable.", code="member_not_found")
    context = get_organization_context(db, user, member.organization_id)
    PermissionService(db).require(context.membership, permission)
    return member, context


@router.get("/members/{member_id}", summary="Détail d'un membre")
def read_member(
    db: DbSession, user: CurrentUser, member_id: uuid.UUID
) -> dict[str, Any]:
    member, _ = _guarded_member(db, user, member_id, "member.view")
    return success(dump(MemberRead.model_validate(member)))


@router.put("/members/{member_id}", summary="Mettre à jour un membre")
def update_member(
    db: DbSession, user: CurrentUser, member_id: uuid.UUID, payload: MemberUpdate
) -> dict[str, Any]:
    member, context = _guarded_member(db, user, member_id, "member.edit")
    updated = MemberService(db).update(member, payload, context.membership)
    return success(dump(MemberRead.model_validate(updated)))


@router.patch("/members/{member_id}", summary="Mise à jour partielle d'un membre")
def patch_member(
    db: DbSession, user: CurrentUser, member_id: uuid.UUID, payload: MemberUpdate
) -> dict[str, Any]:
    return update_member(db, user, member_id, payload)


@router.get("/members/{member_id}/stats", summary="Statistiques d'un membre")
def read_member_stats(
    db: DbSession, user: CurrentUser, member_id: uuid.UUID
) -> dict[str, Any]:
    _guarded_member(db, user, member_id, "member.view")
    # TODO(tontines): calculer depuis les cotisations et versements réels.
    return success(dump(MemberStats()))
