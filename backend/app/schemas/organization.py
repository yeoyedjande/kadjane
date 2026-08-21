from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import EmailStr, Field

from app.models.enums import OrganizationStatus
from app.schemas.base import CamelModel


class OrganizationSettings(CamelModel):
    require_full_payment_before_draw: bool = True
    allow_draw_override: bool = True
    late_payment_grace_days: int = 3
    notify_before_due_days: int = 3


class OrganizationRead(CamelModel):
    id: uuid.UUID
    name: str
    slug: str
    description: str | None = None
    logo_url: str | None = None
    currency: str = "XOF"
    country: str = "CI"
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    rules: str | None = None
    settings: OrganizationSettings = Field(default_factory=OrganizationSettings)
    status: OrganizationStatus = OrganizationStatus.ACTIVE
    created_by: uuid.UUID | None = None
    created_at: datetime


class OrganizationCreate(CamelModel):
    name: str = Field(min_length=2, max_length=180)
    currency: str = Field(default="XOF", min_length=3, max_length=3)
    country: str = Field(default="CI", min_length=2, max_length=2)
    description: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    address: str | None = None
    rules: str | None = None
    settings: OrganizationSettings | None = None


class OrganizationUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=2, max_length=180)
    description: str | None = None
    logo_url: str | None = None
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    country: str | None = Field(default=None, min_length=2, max_length=2)
    phone: str | None = None
    email: EmailStr | None = None
    address: str | None = None
    rules: str | None = None
    settings: OrganizationSettings | None = None
    status: OrganizationStatus | None = None
