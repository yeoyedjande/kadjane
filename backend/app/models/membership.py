from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import MemberStatus, OrgRole

if TYPE_CHECKING:
    from app.models.organization import Organization
    from app.models.user import User


class OrganizationMember(Base, TimestampMixin):
    """Appartenance d'un utilisateur à une organisation.

    C'est cette table qui porte l'isolation multi-association : aucun accès
    aux données d'une organisation sans ligne correspondante.
    """

    __tablename__ = "organization_members"
    __table_args__ = (
        UniqueConstraint(
            "organization_id", "user_id", name="uq_organization_members_org_user"
        ),
        UniqueConstraint(
            "organization_id",
            "member_number",
            name="uq_organization_members_org_number",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    role: Mapped[str] = mapped_column(
        String(32), nullable=False, default=OrgRole.MEMBER.value, index=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=MemberStatus.ACTIVE.value, index=True
    )
    member_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    organization: Mapped[Organization] = relationship(back_populates="members")
    user: Mapped[User] = relationship(back_populates="memberships")

    @property
    def role_enum(self) -> OrgRole:
        return OrgRole(self.role)
