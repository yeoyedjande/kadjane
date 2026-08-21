from __future__ import annotations

import uuid

from sqlalchemy import Select, func, or_, select
from sqlalchemy.orm import Session, joinedload

from app.models.enums import MemberStatus, OrgRole
from app.models.membership import OrganizationMember
from app.models.user import User


class MemberRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def by_id(self, member_id: uuid.UUID) -> OrganizationMember | None:
        statement = (
            select(OrganizationMember)
            .options(joinedload(OrganizationMember.user))
            .where(OrganizationMember.id == member_id)
        )
        return self.db.scalars(statement).first()

    def membership(
        self, organization_id: uuid.UUID, user_id: uuid.UUID
    ) -> OrganizationMember | None:
        statement = (
            select(OrganizationMember)
            .options(joinedload(OrganizationMember.user))
            .where(
                OrganizationMember.organization_id == organization_id,
                OrganizationMember.user_id == user_id,
            )
        )
        return self.db.scalars(statement).first()

    def count(self, organization_id: uuid.UUID) -> int:
        return int(
            self.db.scalar(
                select(func.count())
                .select_from(OrganizationMember)
                .where(OrganizationMember.organization_id == organization_id)
            )
            or 0
        )

    def officers(self, organization_id: uuid.UUID) -> list[OrganizationMember]:
        officer_roles = [
            role.value for role in OrgRole if role.is_officer
        ]
        statement = (
            select(OrganizationMember)
            .options(joinedload(OrganizationMember.user))
            .where(
                OrganizationMember.organization_id == organization_id,
                OrganizationMember.role.in_(officer_roles),
            )
        )
        members = list(self.db.scalars(statement).unique())
        members.sort(key=lambda m: -OrgRole(m.role).level)
        return members

    def search(
        self,
        organization_id: uuid.UUID,
        *,
        query: str = "",
        role: OrgRole | None = None,
        status: MemberStatus | None = None,
        page: int = 0,
        page_size: int = 20,
    ) -> tuple[list[OrganizationMember], int]:
        """Retourne `(page de membres, total)` pour l'organisation donnée."""
        base = self._filtered(organization_id, query, role, status)

        total = int(
            self.db.scalar(
                select(func.count()).select_from(base.subquery())
            )
            or 0
        )

        statement = (
            base.options(joinedload(OrganizationMember.user))
            .order_by(OrganizationMember.member_number.asc(), User.last_name.asc())
            .offset(max(page, 0) * page_size)
            .limit(page_size)
        )
        return list(self.db.scalars(statement).unique()), total

    def add(self, member: OrganizationMember) -> OrganizationMember:
        self.db.add(member)
        self.db.flush()
        return member

    def next_member_number(self, organization_id: uuid.UUID) -> str:
        return f"M-{self.count(organization_id) + 1:03d}"

    # --- Interne ------------------------------------------------------------

    def _filtered(
        self,
        organization_id: uuid.UUID,
        query: str,
        role: OrgRole | None,
        status: MemberStatus | None,
    ) -> Select[tuple[OrganizationMember]]:
        statement = (
            select(OrganizationMember)
            .join(User, User.id == OrganizationMember.user_id)
            .where(OrganizationMember.organization_id == organization_id)
        )
        term = query.strip()
        if term:
            pattern = f"%{term.lower()}%"
            statement = statement.where(
                or_(
                    func.lower(User.first_name).like(pattern),
                    func.lower(User.last_name).like(pattern),
                    func.lower(User.phone).like(pattern),
                    func.lower(func.coalesce(User.email, "")).like(pattern),
                    func.lower(
                        func.coalesce(OrganizationMember.member_number, "")
                    ).like(pattern),
                )
            )
        if role is not None:
            statement = statement.where(OrganizationMember.role == role.value)
        if status is not None:
            statement = statement.where(OrganizationMember.status == status.value)
        return statement
