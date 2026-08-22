"""Cotisations de caisse : les sommes dues à l'association, hors tontine.

Distinct des tontines. Une tontine redistribue : chacun cotise, chacun reçoit
la cagnotte à son tour. La caisse, elle, ne redistribue pas — elle finance le
fonctionnement de l'association. Un membre qui cotise à la caisse n'en attend
aucun versement en retour.

Le découpage en périodes réutilise `app.services.period_service`, déjà employé
par les cycles de tontine : la mécanique est la même, seule la finalité change.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin, new_uuid
from app.models.enums import (
    ContributionStatus,
    DuesPlanStatus,
    PaymentStatus,
    TontineFrequency,
)
from app.models.membership import OrganizationMember


class DuesPlan(Base, TimestampMixin):
    """Une cotisation périodique due par tous les membres actifs.

    Le montant est identique pour tous — c'est la règle d'une caisse commune.
    Plusieurs plans peuvent coexister dans une organisation : « Caisse de
    solidarité » et « Fonds événement » sont deux plans distincts.
    """

    __tablename__ = "dues_plans"
    __table_args__ = (
        UniqueConstraint("organization_id", "name", name="uq_dues_plans_org_name"),
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
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="XOF")
    frequency: Mapped[str] = mapped_column(
        String(20), nullable=False, default=TontineFrequency.MONTHLY.value
    )
    # Rang du jour d'échéance dans la période : le 5 du mois, par défaut.
    due_day: Mapped[int] = mapped_column(Integer, nullable=False, default=5)
    custom_period_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=DuesPlanStatus.ACTIVE.value
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )

    entries: Mapped[list[DuesEntry]] = relationship(
        back_populates="plan", cascade="all, delete-orphan"
    )

    @property
    def status_enum(self) -> DuesPlanStatus:
        return DuesPlanStatus(self.status)

    @property
    def frequency_enum(self) -> TontineFrequency:
        return TontineFrequency(self.frequency)

    @property
    def is_open(self) -> bool:
        """Un plan clos ou suspendu n'engendre plus d'échéance."""
        return self.status == DuesPlanStatus.ACTIVE.value


class DuesEntry(Base, TimestampMixin):
    """Ce qu'un membre doit pour une période donnée d'un plan.

    Une ligne par membre actif et par période. `paid_amount` est un cumul
    dérivé des paiements `confirmed` seulement, recalculé par le service : il
    ne se met jamais à jour tout seul — même règle que `Contribution`.
    """

    __tablename__ = "dues_entries"
    __table_args__ = (
        UniqueConstraint(
            "plan_id",
            "member_id",
            "sequence_number",
            name="uq_dues_entries_plan_member_period",
        ),
        Index("ix_dues_entries_plan_status", "plan_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("dues_plans.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # `RESTRICT` plutôt que `CASCADE` : supprimer un membre ne doit pas effacer
    # ses règlements passés. `MemberService.delete` refuse déjà la suppression
    # d'un membre porteur d'un historique financier.
    member_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organization_members.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    sequence_number: Mapped[int] = mapped_column(Integer, nullable=False)
    period_label: Mapped[str] = mapped_column(String(60), nullable=False)
    period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    period_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    due_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expected_amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    paid_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ContributionStatus.PENDING.value
    )

    plan: Mapped[DuesPlan] = relationship(back_populates="entries")
    member: Mapped[OrganizationMember] = relationship()
    payments: Mapped[list[DuesPayment]] = relationship(
        back_populates="entry",
        cascade="all, delete-orphan",
        order_by="DuesPayment.created_at",
    )

    @property
    def status_enum(self) -> ContributionStatus:
        return ContributionStatus(self.status)

    @property
    def remaining_amount(self) -> Decimal:
        return max(Decimal("0"), self.expected_amount - self.paid_amount)

    @property
    def is_settled(self) -> bool:
        return self.status in {
            ContributionStatus.PAID.value,
            ContributionStatus.CANCELLED.value,
        }


class DuesPayment(Base, TimestampMixin):
    """Un règlement enregistré pour une échéance de caisse.

    Table distincte des `payments` de tontine : l'argent de la caisse et celui
    des cagnottes ne se mélangent pas, et la trésorerie les additionne
    explicitement. Un règlement annulé reste dans l'historique — aucune
    écriture financière n'est supprimée.
    """

    __tablename__ = "dues_payments"
    __table_args__ = (Index("ix_dues_payments_entry_status", "entry_id", "status"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entry_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("dues_entries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(24), nullable=False)
    reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=PaymentStatus.CONFIRMED.value
    )
    recorded_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancel_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    entry: Mapped[DuesEntry] = relationship(back_populates="payments")

    @property
    def status_enum(self) -> PaymentStatus:
        return PaymentStatus(self.status)
