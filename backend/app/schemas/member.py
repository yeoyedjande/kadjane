from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Generic, TypeVar

from pydantic import EmailStr, Field

from app.models.enums import Gender, MemberStatus, OrgRole
from app.schemas.base import CamelModel
from app.schemas.user import UserRead

T = TypeVar("T")


class MemberRead(CamelModel):
    id: uuid.UUID
    organization_id: uuid.UUID
    user: UserRead
    role: OrgRole = OrgRole.MEMBER
    status: MemberStatus = MemberStatus.ACTIVE
    joined_at: datetime
    member_number: str | None = None


class MemberCreate(CamelModel):
    """Ajout d'un membre : l'utilisateur est créé s'il n'existe pas encore.

    `password` est le mot de passe provisoire remis au membre. Omis, un mot de
    passe est tiré au hasard et renvoyé **une seule fois** dans la réponse de
    création, pour que l'administrateur puisse le transmettre. Il est ignoré si
    le numéro correspond à un compte déjà existant : on ne réinitialise pas le
    mot de passe de quelqu'un en l'ajoutant à une organisation.
    """

    password: str | None = Field(default=None, min_length=8, max_length=128)
    first_name: str = Field(min_length=1, max_length=120)
    last_name: str = Field(min_length=1, max_length=120)
    phone: str = Field(min_length=4, max_length=32)
    role: OrgRole = OrgRole.MEMBER
    status: MemberStatus = MemberStatus.ACTIVE
    email: EmailStr | None = None
    gender: Gender = Gender.UNSPECIFIED
    birth_date: date | None = None
    avatar_url: str | None = None
    member_number: str | None = None


class MemberUpdate(CamelModel):
    role: OrgRole | None = None
    status: MemberStatus | None = None
    member_number: str | None = None
    # Identité portée par l'utilisateur rattaché.
    first_name: str | None = Field(default=None, min_length=1, max_length=120)
    last_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, min_length=4, max_length=32)
    email: EmailStr | None = None
    gender: Gender | None = None
    birth_date: date | None = None
    avatar_url: str | None = None


class MemberStats(CamelModel):
    """Statistiques d'un membre.

    TODO(tontines): alimenter depuis les cotisations et versements réels une
    fois le métier tontine migré (session suivante).
    """

    total_paid: float = 0
    total_received: float = 0
    tontines_count: int = 0
    pending_contributions: int = 0
    late_contributions: int = 0


class Page(CamelModel, Generic[T]):
    """`paged<T>` du contrat : `{items, page, hasMore, total}`.

    `page` est indexée à partir de 0, comme l'attend l'application Flutter.
    """

    items: list[T]
    page: int
    page_size: int
    has_more: bool
    total: int
