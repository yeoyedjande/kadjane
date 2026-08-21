from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.membership import OrganizationMember
from app.models.organization import Organization


class OrganizationRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_id(self, organization_id: uuid.UUID) -> Organization | None:
        return self.db.get(Organization, organization_id)

    def by_slug(self, slug: str) -> Organization | None:
        return self.db.scalars(
            select(Organization).where(Organization.slug == slug)
        ).first()

    def for_user(self, user_id: uuid.UUID) -> list[Organization]:
        """Uniquement les organisations où l'utilisateur est membre."""
        statement = (
            select(Organization)
            .join(
                OrganizationMember,
                OrganizationMember.organization_id == Organization.id,
            )
            .where(OrganizationMember.user_id == user_id)
            .order_by(Organization.created_at.asc())
        )
        return list(self.db.scalars(statement).unique())

    def add(self, organization: Organization) -> Organization:
        self.db.add(organization)
        self.db.flush()
        return organization

    def with_members(self, organization_id: uuid.UUID) -> Organization | None:
        statement = (
            select(Organization)
            .options(selectinload(Organization.members))
            .where(Organization.id == organization_id)
        )
        return self.db.scalars(statement).first()
