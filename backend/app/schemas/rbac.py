from __future__ import annotations

import uuid

from pydantic import Field, field_validator

from app.models.enums import RoleStatus
from app.schemas.base import CamelModel


def _slug(value: object) -> object:
    """Normalise un code de rôle : minuscules, tirets, sans espaces."""
    if not isinstance(value, str):
        return value
    cleaned = "-".join(value.strip().lower().split())
    return "".join(character for character in cleaned if character.isalnum() or character in "-_")


class RoleCreate(CamelModel):
    """Rôle sur mesure d'une organisation.

    Le code est dérivé du nom s'il n'est pas fourni : l'administrateur pense en
    « Responsable Cotisations », pas en identifiant.
    """

    name: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=2000)
    code: str | None = Field(default=None, max_length=64)
    permissions: list[str] = Field(default_factory=list)

    _normalize_code = field_validator("code", mode="before")(_slug)


class RoleUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    status: RoleStatus | None = None


class RolePermissionsUpdate(CamelModel):
    """Remplace intégralement les droits d'un rôle.

    Un remplacement plutôt qu'un delta : la console envoie l'état des cases
    cochées, et deux administrateurs qui enregistrent en même temps ne
    fusionnent pas silencieusement leurs intentions.
    """

    permissions: list[str] = Field(default_factory=list)


class MemberRoleUpdate(CamelModel):
    """Change le rôle d'un membre.

    `roleId` désigne un rôle sur mesure ; `role` l'étiquette système. L'un des
    deux suffit — fournir `roleId` seul est la voie normale depuis la console.
    """

    role: str | None = Field(default=None, max_length=32)
    role_id: uuid.UUID | None = None
