from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import (
    CashboxStatus,
    CashTransactionStatus,
    TransactionCategory,
    TransactionType,
)


class Cashbox(Base, TimestampMixin):
    """Une caisse de l'association : un pot d'argent identifié.

    Plusieurs caisses coexistent — « Caisse principale », « Caisse sociale »,
    « Événements » — pour que le trésorier sache où va chaque franc sans tenir
    de comptabilité parallèle.

    Le solde **n'est pas stocké**. Il se calcule : solde d'ouverture, plus les
    entrées confirmées, moins les sorties confirmées. Une colonne
    `current_balance` finirait par diverger du journal le jour où une écriture
    serait annulée sans repasser par le service — et c'est le journal qui fait
    foi, pas le total.
    """

    __tablename__ = "cashboxes"
    __table_args__ = (
        UniqueConstraint("organization_id", "name", name="uq_cashboxes_organization_id"),
        Index("ix_cashboxes_org_status", "organization_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="XOF")
    opening_balance: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=CashboxStatus.OPEN.value
    )
    # Caisse par défaut de l'organisation : celle que reçoit un encaissement
    # dont personne n'a précisé la destination.
    is_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    transactions: Mapped[list[CashTransaction]] = relationship(
        back_populates="cashbox"
    )

    @property
    def status_enum(self) -> CashboxStatus:
        return CashboxStatus(self.status)

    @property
    def accepts_transactions(self) -> bool:
        return self.status_enum.accepts_transactions


class CashTransaction(Base, TimestampMixin):
    """Un mouvement dans une caisse.

    Deux origines, une seule table : la saisie manuelle du trésorier (don,
    frais, événement) et l'écriture **engendrée** par un règlement de campagne
    confirmé. La seconde porte `campaign_payment_id` : c'est ce lien qui
    garantit qu'un encaissement ne soit jamais saisi deux fois.

    Les cotisations de tontine restent en dehors : elles alimentent la cagnotte
    du cycle, pas la caisse de l'association.

    Une écriture ne se supprime pas — elle passe à `cancelled` ou `reversed`,
    et sort du solde sans sortir du journal.
    """

    __tablename__ = "cash_transactions"
    __table_args__ = (
        Index("ix_cash_transactions_org_date", "organization_id", "date"),
        Index("ix_cash_transactions_box_status", "cashbox_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Nul pour les lignes antérieures aux caisses : la migration les rattache
    # à la « Caisse principale » créée pour chaque organisation.
    cashbox_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("cashboxes.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="SET NULL"), nullable=True
    )
    type: Mapped[str] = mapped_column(
        String(16), nullable=False, default=TransactionType.INCOME.value
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=CashTransactionStatus.CONFIRMED.value
    )
    reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
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
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancel_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    cashbox: Mapped[Cashbox | None] = relationship(back_populates="transactions")

    @property
    def status_enum(self) -> CashTransactionStatus:
        return CashTransactionStatus(self.status)

    @property
    def counts_in_balance(self) -> bool:
        return self.status_enum.counts_in_balance

    @property
    def signed_amount(self) -> Decimal:
        """Effet de l'écriture sur le solde, annulations exclues.

        `ADJUSTMENT` porte son signe dans le montant : une correction peut
        aussi bien ajouter que retrancher, et lui imposer un sens obligerait à
        saisir deux fois la même réalité.
        """
        if not self.counts_in_balance:
            return Decimal("0")
        direction = TransactionType(self.type).direction
        return self.amount if direction == 0 else self.amount * direction
