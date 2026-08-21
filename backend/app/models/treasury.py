from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Index, Numeric, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import TransactionCategory, TransactionType


class CashTransaction(Base, TimestampMixin):
    """Mouvement de caisse saisi manuellement (don, frais, événement…).

    Les cotisations et les versements ne sont **pas** dupliqués ici : la
    trésorerie les agrège directement depuis `payments` et `payouts`, ce qui
    évite deux vérités pour un même euro.
    """

    __tablename__ = "cash_transactions"
    __table_args__ = (
        Index("ix_cash_transactions_org_date", "organization_id", "date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="SET NULL"), nullable=True
    )
    type: Mapped[str] = mapped_column(
        String(16), nullable=False, default=TransactionType.INCOME.value
    )
    category: Mapped[str] = mapped_column(
        String(24), nullable=False, default=TransactionCategory.OTHER.value
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )

    @property
    def signed_amount(self) -> Decimal:
        return (
            self.amount
            if self.type == TransactionType.INCOME.value
            else -self.amount
        )
