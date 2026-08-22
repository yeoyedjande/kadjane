"""Matrice des droits par rôle — copie serveur de `PermissionService` Flutter.

Le backend est la source de vérité : l'application applique la matrice qu'il
renvoie. Tant que les rôles personnalisés ne sont pas persistés, la matrice
par défaut est servie telle quelle.
"""

from __future__ import annotations

from app.core.errors import PermissionDeniedError
from app.models.enums import OrgRole

MEMBER_PERMISSIONS: set[str] = {
    "organization.view",
    "member.view",
    "tontine.view",
    "contribution.view",
    "draw.view",
    "payout.view",
    "reminder.view",
    "dues.view",
}

AUDITOR_PERMISSIONS: set[str] = MEMBER_PERMISSIONS | {
    "treasury.view",
    "report.view",
    "audit.view",
}

TREASURER_PERMISSIONS: set[str] = AUDITOR_PERMISSIONS | {
    "contribution.record",
    "contribution.confirm",
    "contribution.cancel",
    "payout.record",
    "treasury.manage",
    "dues.record",
    "reminder.send",
}

PRESIDENT_PERMISSIONS: set[str] = AUDITOR_PERMISSIONS | {
    "tontine.validate",
    "draw.run",
    "member.invite",
    "reminder.send",
}

ADMIN_PERMISSIONS: set[str] = (
    TREASURER_PERMISSIONS
    | PRESIDENT_PERMISSIONS
    | {
        "organization.edit",
        "organization.manage_officers",
        "member.create",
        "member.edit",
        "member.delete",
        "dues.manage",
        "tontine.create",
        "tontine.edit",
        "draw.override",
        "draw.invalidate",
    }
)

ALL_PERMISSIONS: set[str] = ADMIN_PERMISSIONS | {
    "organization.view",
    "audit.view",
}

DEFAULT_MATRIX: dict[OrgRole, set[str]] = {
    OrgRole.SUPER_ADMIN: ALL_PERMISSIONS,
    OrgRole.ORGANIZATION_ADMIN: ADMIN_PERMISSIONS,
    OrgRole.PRESIDENT: PRESIDENT_PERMISSIONS,
    OrgRole.TREASURER: TREASURER_PERMISSIONS,
    OrgRole.AUDITOR: AUDITOR_PERMISSIONS,
    OrgRole.MEMBER: MEMBER_PERMISSIONS,
}


def permissions_of(role: OrgRole) -> set[str]:
    return DEFAULT_MATRIX.get(role, MEMBER_PERMISSIONS)


def can(role: OrgRole, permission: str) -> bool:
    return permission in permissions_of(role)


def require(role: OrgRole, permission: str) -> None:
    """Lève `PermissionDeniedError` si le rôle ne porte pas la permission."""
    if not can(role, permission):
        raise PermissionDeniedError(
            "Votre rôle ne permet pas cette action.",
            details={"requiredPermission": permission, "role": role.value},
        )
