from __future__ import annotations

import uuid
from typing import TYPE_CHECKING, Any

from sqlalchemy import JSON, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import OrganizationStatus

if TYPE_CHECKING:
    from app.models.membership import OrganizationMember

DEFAULT_SETTINGS: dict[str, Any] = {
    "requireFullPaymentBeforeDraw": True,
    "allowDrawOverride": True,
    "latePaymentGraceDays": 3,
    "notifyBeforeDueDays": 3,
}


class Organization(Base, TimestampMixin):
    __tablename__ = "organizations"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    name: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    slug: Mapped[str] = mapped_column(
        String(200), unique=True, index=True, nullable=False
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    country: Mapped[str] = mapped_column(String(2), nullable=False, default="CI")
    currency: Mapped[str] = mapped_column(String(3), nullable=False, default="XOF")
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    rules: Mapped[str | None] = mapped_column(Text, nullable=True)
    settings: Mapped[dict[str, Any]] = mapped_column(
        JSON, nullable=False, default=lambda: dict(DEFAULT_SETTINGS)
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=OrganizationStatus.ACTIVE.value
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    members: Mapped[list[OrganizationMember]] = relationship(
        back_populates="organization", cascade="all, delete-orphan"
    )
