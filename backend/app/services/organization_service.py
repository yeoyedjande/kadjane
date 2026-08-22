from __future__ import annotations

import re
import unicodedata
import uuid

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models.enums import MemberStatus, OrgRole
from app.models.membership import OrganizationMember
from app.models.organization import DEFAULT_SETTINGS, Organization
from app.models.user import User
from app.repositories.member_repository import MemberRepository
from app.repositories.organization_repository import OrganizationRepository
from app.schemas.organization import OrganizationCreate, OrganizationUpdate

_SLUG_PATTERN = re.compile(r"[^a-z0-9]+")


def slugify(value: str) -> str:
    """`Association Solidarité` -> `association-solidarite`."""
    ascii_form = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
    )
    base = _SLUG_PATTERN.sub("-", ascii_form.strip().lower()).strip("-")
    return base or "organisation"


# Colonnes non nulles en base : un `null` reçu ne doit pas les écraser.
_REQUIRED_FIELDS = frozenset({"name", "currency", "country", "status"})


class OrganizationService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.organizations = OrganizationRepository(db)
        self.members = MemberRepository(db)

    def list_for_user(self, user_id: uuid.UUID) -> list[Organization]:
        return self.organizations.for_user(user_id)

    def get(self, organization_id: uuid.UUID) -> Organization:
        organization = self.organizations.by_id(organization_id)
        if organization is None:
            raise NotFoundError("Organisation introuvable.", code="organization_not_found")
        return organization

    def create(self, payload: OrganizationCreate, owner: User) -> Organization:
        """Crée l'organisation et y inscrit son créateur comme administrateur."""
        settings = (
            payload.settings.model_dump(by_alias=True)
            if payload.settings is not None
            else dict(DEFAULT_SETTINGS)
        )
        organization = Organization(
            name=payload.name.strip(),
            slug=self._unique_slug(payload.name),
            description=payload.description,
            country=payload.country.upper(),
            currency=payload.currency.upper(),
            phone=payload.phone,
            email=payload.email,
            address=payload.address,
            rules=payload.rules,
            settings=settings,
            created_by=owner.id,
        )
        self.organizations.add(organization)
        self.members.add(
            OrganizationMember(
                organization_id=organization.id,
                user_id=owner.id,
                role=OrgRole.ORGANIZATION_ADMIN.value,
                status=MemberStatus.ACTIVE.value,
                member_number="M-001",
            )
        )
        self.db.commit()
        self.db.refresh(organization)
        return organization

    def update(
        self, organization: Organization, payload: OrganizationUpdate
    ) -> Organization:
        # `exclude_unset` seul : un champ explicitement mis à `null` doit
        # pouvoir **effacer** la valeur. Écarter tous les `None` interdisait de
        # vider un e-mail ou une adresse une fois renseignés.
        data = payload.model_dump(exclude_unset=True)
        settings = data.pop("settings", None)
        for field, value in data.items():
            # Les colonnes obligatoires ne s'effacent pas : un `null` y est
            # traité comme « ne pas toucher ».
            if value is None and field in _REQUIRED_FIELDS:
                continue
            if field in {"currency", "country"} and isinstance(value, str):
                value = value.upper()
            if field == "status":
                value = getattr(value, "value", value)
            setattr(organization, field, value)
        if settings is not None:
            merged = dict(organization.settings or DEFAULT_SETTINGS)
            merged.update(payload.settings.model_dump(by_alias=True))
            organization.settings = merged
        self.db.commit()
        self.db.refresh(organization)
        return organization

    # --- Interne -------------------------------------------------------------

    def _unique_slug(self, name: str) -> str:
        base = slugify(name)
        candidate = base
        suffix = 2
        while self.organizations.by_slug(candidate) is not None:
            candidate = f"{base}-{suffix}"
            suffix += 1
        return candidate
