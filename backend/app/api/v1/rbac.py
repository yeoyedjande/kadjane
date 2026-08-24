"""Rôles, permissions et attribution — le RBAC administrable.

Deux principes gouvernent ce module :

* **Personnaliser n'affecte que soi.** Toucher à un rôle système global le
  recopie d'abord au profit de l'organisation : le trésorier d'une association
  ne change pas parce qu'une autre a ajusté le sien.
* **On ne se hisse pas soi-même.** Attribuer un rôle plus fort que le sien est
  refusé, et un rôle sur mesure compte au niveau le plus bas — sans quoi
  `role.create` suffirait à se fabriquer les pleins pouvoirs.
"""

from __future__ import annotations

import uuid
from typing import Annotated, Any

from fastapi import APIRouter, Query, status
from sqlalchemy import func, select

from app.core.deps import CurrentUser, DbSession, OrgContext
from app.core.errors import ConflictError, NotFoundError, PermissionDeniedError
from app.core.responses import success
from app.models.enums import AuditAction, OrgRole, RoleStatus
from app.models.membership import OrganizationMember
from app.models.rbac import Permission, Role
from app.rbac import catalog
from app.schemas.rbac import (
    MemberRoleUpdate,
    RoleCreate,
    RolePermissionsUpdate,
    RoleUpdate,
)
from app.services.audit_service import AuditService
from app.services.permission_service import PermissionService

router = APIRouter(tags=["rôles et permissions"])


# --- Catalogue ---------------------------------------------------------------


@router.get("/permissions", summary="Catalogue des permissions")
def list_permissions(db: DbSession, user: CurrentUser) -> dict[str, Any]:
    """Toutes les permissions que le backend sait exiger, groupées par catégorie.

    Le catalogue décrit le produit, pas une organisation : il est identique
    pour tout le monde et se lit avec une simple session. C'est ce que la
    console affiche en colonnes de cases à cocher.
    """
    permissions = list(db.scalars(select(Permission).order_by(Permission.code)))
    if not permissions:
        # Base pas encore semée : servir le catalogue du code plutôt que rien,
        # sinon la console afficherait une page vide sans expliquer pourquoi.
        return success(
            [_spec_payload(spec) for spec in catalog.CATALOG],
            meta={"categories": list(catalog.CATEGORIES), "source": "catalog"},
        )
    return success(
        [_permission_payload(permission) for permission in permissions],
        meta={"categories": list(catalog.CATEGORIES), "source": "database"},
    )


@router.get("/me/permissions", summary="Mes rôles et mes droits")
def read_my_permissions(
    db: DbSession,
    user: CurrentUser,
    organization_id: Annotated[
        uuid.UUID | None, Query(alias="organizationId")
    ] = None,
) -> dict[str, Any]:
    """Une entrée par appartenance : le rôle **dépend** de l'organisation.

    Toujours un tableau, même filtré sur une seule organisation — un membre
    peut être trésorier ici et simple membre ailleurs, et l'application doit
    pouvoir changer d'organisation sans redemander ses droits.
    """
    service = PermissionService(db)
    statement = select(OrganizationMember).where(
        OrganizationMember.user_id == user.id
    )
    if organization_id is not None:
        statement = statement.where(
            OrganizationMember.organization_id == organization_id
        )

    payload: list[dict[str, Any]] = []
    for membership in db.scalars(statement):
        role = (
            service.role_for(membership.organization_id, membership.role_id)
            if membership.role_id
            else None
        )
        payload.append(
            {
                "organizationId": str(membership.organization_id),
                "memberId": str(membership.id),
                "role": membership.role,
                "roleId": str(role.id) if role else None,
                "roleName": role.name if role else _system_label(membership.role),
                "permissions": sorted(service.permissions_for(membership)),
            }
        )
    return success(payload)


# --- Rôles -------------------------------------------------------------------


@router.get("/organizations/{organization_id}/roles", summary="Rôles de l'organisation")
def list_roles(db: DbSession, context: OrgContext) -> dict[str, Any]:
    """Rôles système et rôles sur mesure, avec leurs droits.

    Lisible par tout membre : l'application mobile s'en sert pour adapter ses
    écrans, et masquer la liste ne protégerait rien — le backend refuse de
    toute façon les actions non autorisées.
    """
    service = PermissionService(db)
    counts = _member_counts(db, context.organization_id)
    return success(
        [
            _role_payload(role, context.organization_id, counts)
            for role in service.roles_of(context.organization_id)
        ]
    )


@router.post(
    "/organizations/{organization_id}/roles",
    status_code=status.HTTP_201_CREATED,
    summary="Créer un rôle sur mesure",
)
def create_role(
    db: DbSession, context: OrgContext, payload: RoleCreate
) -> dict[str, Any]:
    service = PermissionService(db)
    service.require(context.membership, "role.create")

    code = payload.code or _slugify(payload.name)
    if not code:
        raise ConflictError("Le nom du rôle ne produit aucun code exploitable.", code="role_code_empty")
    if _role_by_code(db, context.organization_id, code) is not None:
        raise ConflictError(
            "Un rôle porte déjà ce code dans cette organisation.",
            code="role_code_taken",
        )

    granted = _grantable(service, context.membership, set(payload.permissions))
    role = Role(
        organization_id=context.organization_id,
        code=code,
        name=payload.name,
        description=payload.description,
        is_system=False,
        status=RoleStatus.ACTIVE.value,
        created_by=context.membership.id,
    )
    db.add(role)
    db.flush()
    service.set_permissions(role, granted)

    AuditService(db).record(
        organization_id=context.organization_id,
        action=AuditAction.ROLE_CREATED,
        description=f"Rôle « {role.name} » créé avec {len(granted)} permission(s).",
        actor=context.membership,
        target_type="role",
        target_id=role.id,
        metadata={"code": role.code, "permissions": sorted(granted)},
    )
    db.commit()
    return success(_role_payload(role, context.organization_id, {}))


@router.patch(
    "/organizations/{organization_id}/roles/{role_id}", summary="Modifier un rôle"
)
def update_role(
    db: DbSession, context: OrgContext, role_id: uuid.UUID, payload: RoleUpdate
) -> dict[str, Any]:
    service = PermissionService(db)
    service.require(context.membership, "role.update")
    role = _own_role(service, context, role_id)

    changes: dict[str, Any] = {}
    if payload.name is not None:
        changes["name"] = payload.name
        role.name = payload.name
    if payload.description is not None:
        role.description = payload.description
    if payload.status is not None:
        if role.is_system and payload.status is RoleStatus.DISABLED:
            # Désactiver « Membre » priverait de droits tous ceux qui n'ont pas
            # de rôle explicite : le produit ne survivrait pas à ce clic.
            raise ConflictError(
                "Un rôle système ne peut pas être désactivé.",
                code="system_role_locked",
            )
        changes["status"] = payload.status.value
        role.status = payload.status.value

    AuditService(db).record(
        organization_id=context.organization_id,
        action=AuditAction.ROLE_UPDATED,
        description=f"Rôle « {role.name} » modifié.",
        actor=context.membership,
        target_type="role",
        target_id=role.id,
        metadata=changes,
    )
    db.commit()
    return success(
        _role_payload(role, context.organization_id, _member_counts(db, context.organization_id))
    )


@router.put(
    "/organizations/{organization_id}/roles/{role_id}/permissions",
    summary="Attribuer les permissions d'un rôle",
)
def set_role_permissions(
    db: DbSession,
    context: OrgContext,
    role_id: uuid.UUID,
    payload: RolePermissionsUpdate,
) -> dict[str, Any]:
    service = PermissionService(db)
    service.require(context.membership, "permission.assign")
    role = _own_role(service, context, role_id)

    before = role.permission_codes
    granted = _grantable(service, context.membership, set(payload.permissions))
    applied = service.set_permissions(role, granted)

    AuditService(db).record(
        organization_id=context.organization_id,
        action=AuditAction.ROLE_PERMISSIONS_CHANGED,
        description=(
            f"Droits du rôle « {role.name} » : "
            f"{len(before)} → {len(applied)} permission(s)."
        ),
        actor=context.membership,
        target_type="role",
        target_id=role.id,
        metadata={
            "added": sorted(applied - before),
            "removed": sorted(before - applied),
        },
    )
    db.commit()
    return success(
        _role_payload(role, context.organization_id, _member_counts(db, context.organization_id))
    )


@router.patch(
    "/organizations/{organization_id}/members/{member_id}/role",
    summary="Changer le rôle d'un membre",
)
def assign_member_role(
    db: DbSession, context: OrgContext, member_id: uuid.UUID, payload: MemberRoleUpdate
) -> dict[str, Any]:
    service = PermissionService(db)
    service.require(context.membership, "role.assign")

    member = db.get(OrganizationMember, member_id)
    if member is None or member.organization_id != context.organization_id:
        raise NotFoundError("Membre introuvable.", code="member_not_found")

    actor_level = context.membership.role_enum.level
    if member.id != context.membership.id and member.role_enum.level > actor_level:
        raise PermissionDeniedError(
            "Vous ne pouvez pas modifier un membre dont le rôle dépasse le vôtre.",
            code="role_escalation_denied",
        )

    previous_label = member.role
    previous_role = (
        service.role_for(context.organization_id, member.role_id)
        if member.role_id
        else None
    )
    previous = previous_role.name if previous_role else previous_label
    if payload.role_id is not None:
        # Attribuer n'est pas modifier : on prend le rôle tel qu'il est, sans
        # en fabriquer une copie propre à l'organisation.
        role = service.role_for(context.organization_id, payload.role_id)
        if role is None:
            raise NotFoundError("Rôle introuvable.", code="role_not_found")
        if not role.is_assignable:
            raise ConflictError(
                "Ce rôle est désactivé et ne peut pas être attribué.",
                code="role_disabled",
            )
        _guard_level(role.code, actor_level)
        member.role_id = role.id
        member.role = role.code if role.is_system else OrgRole.MEMBER.value
    elif payload.role is not None:
        _guard_level(payload.role, actor_level)
        system = _role_by_code(db, context.organization_id, payload.role)
        if system is None:
            raise NotFoundError("Rôle introuvable.", code="role_not_found")
        member.role_id = system.id
        member.role = payload.role
    else:
        raise ConflictError("Indiquez `roleId` ou `role`.", code="role_missing")

    # Le **nom** du rôle, pas l'étiquette : un rôle sur mesure laisse
    # l'étiquette à « member », et « member → member » n'apprendrait rien à qui
    # relit le journal.
    assigned = db.get(Role, member.role_id) if member.role_id else None
    assigned_name = assigned.name if assigned else member.role

    AuditService(db).record(
        organization_id=context.organization_id,
        action=AuditAction.MEMBER_ROLE_CHANGED,
        description=(
            f"Rôle de {member.user.full_name} : {previous} → {assigned_name}."
        ),
        actor=context.membership,
        target_type="member",
        target_id=member.id,
        metadata={
            "from": previous,
            "to": assigned_name,
            "label": member.role,
            "roleId": str(member.role_id) if member.role_id else None,
        },
    )
    db.commit()
    db.refresh(member)
    return success(
        {
            "memberId": str(member.id),
            "role": member.role,
            "roleId": str(member.role_id) if member.role_id else None,
            "permissions": sorted(PermissionService(db).permissions_for(member)),
        }
    )


# --- Interne -----------------------------------------------------------------


def _own_role(
    service: PermissionService, context: OrgContext, role_id: uuid.UUID
) -> Role:
    """Rôle modifiable par cette organisation, recopié s'il est encore partagé."""
    role = service.role_for(context.organization_id, role_id)
    if role is None:
        raise NotFoundError("Rôle introuvable.", code="role_not_found")
    if role.organization_id is None:
        role = service.fork_system_role(role, context.organization_id)
    return role


def _grantable(
    service: PermissionService, actor: OrganizationMember, requested: set[str]
) -> set[str]:
    """Retire les permissions que l'auteur ne possède pas lui-même.

    Sans ce filtre, `role.create` permettrait de se fabriquer un rôle portant
    des droits qu'on n'a pas, puis de se l'attribuer : l'escalade se ferait en
    deux appels parfaitement légitimes pris séparément.
    """
    held = service.permissions_for(actor)
    return {code for code in requested if code in held}


def _guard_level(role_code: str, actor_level: int) -> None:
    """Un rôle sur mesure compte au niveau `MEMBER`, le plus bas."""
    try:
        target_level = OrgRole(role_code).level
    except ValueError:
        target_level = OrgRole.MEMBER.level
    if target_level > actor_level:
        raise PermissionDeniedError(
            "Vous ne pouvez pas attribuer un rôle supérieur au vôtre.",
            code="role_escalation_denied",
        )


def _role_by_code(
    db: DbSession, organization_id: uuid.UUID, code: str
) -> Role | None:
    """Rôle de ce code, celui de l'organisation primant sur le gabarit global."""
    own = db.scalars(
        select(Role).where(
            Role.organization_id == organization_id, Role.code == code
        )
    ).first()
    if own is not None:
        return own
    return db.scalars(
        select(Role).where(Role.organization_id.is_(None), Role.code == code)
    ).first()


def _member_counts(db: DbSession, organization_id: uuid.UUID) -> dict[str, int]:
    """Nombre de membres par code de rôle, pour la colonne « Utilisateurs »."""
    rows = db.execute(
        select(OrganizationMember.role, func.count())
        .where(OrganizationMember.organization_id == organization_id)
        .group_by(OrganizationMember.role)
    )
    return {role: int(count) for role, count in rows}


def _role_payload(
    role: Role, organization_id: uuid.UUID, counts: dict[str, int]
) -> dict[str, Any]:
    permissions = sorted(role.permission_codes)
    return {
        "id": str(role.id),
        "organizationId": str(organization_id),
        # Conservé pour l'application mobile et les gardes du back-office, qui
        # indexent la matrice par ce code depuis la première version.
        "role": role.code,
        "code": role.code,
        "name": role.name,
        "description": role.description,
        "isSystem": role.is_system,
        # Vrai quand l'organisation a pris la main sur le gabarit partagé.
        "isCustomized": role.organization_id is not None,
        "status": role.status,
        "permissions": permissions,
        "permissionCount": len(permissions),
        "memberCount": counts.get(role.code, 0),
        "updatedAt": role.updated_at.isoformat() if role.updated_at else None,
    }


def _permission_payload(permission: Permission) -> dict[str, Any]:
    return {
        "id": str(permission.id),
        "code": permission.code,
        "name": permission.name,
        "description": permission.description,
        "category": permission.category,
    }


def _spec_payload(spec: catalog.PermissionSpec) -> dict[str, Any]:
    return {
        "id": spec.code,
        "code": spec.code,
        "name": spec.name,
        "description": spec.description,
        "category": spec.category,
    }


def _system_label(code: str) -> str:
    try:
        return catalog.ROLE_LABELS[OrgRole(code)][0]
    except (ValueError, KeyError):
        return code


def _slugify(value: str) -> str:
    cleaned = "-".join(value.strip().lower().split())
    return "".join(
        character for character in cleaned if character.isalnum() or character in "-_"
    )[:64]
