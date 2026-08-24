"""Campagnes de cotisation : l'engagement, le suivi, le règlement.

Trois notions à ne jamais confondre — c'est la règle qui structure ce module :

* une **campagne** est un engagement financier : ce que l'association attend ;
* un **paiement** est une transaction réelle : ce qu'elle a reçu ;
* une **caisse** représente les fonds détenus.

60 000 FCFA attendus et 40 000 encaissés, ce sont deux nombres différents, et
la caisse n'augmente que du second.

Ce modèle couvre les cotisations **associatives**, **exceptionnelles** et
**volontaires**. Les cotisations de tontine gardent leurs tables — elles
alimentent la cagnotte d'un cycle et se versent au bénéficiaire, pas à la
caisse de l'association (`ContributionType.TONTINE.feeds_cashbox` vaut faux).
Les plans périodiques de caisse (`dues_plans`) restent également en place :
ils engendrent une échéance par période, là où une campagne en pose une seule.
"""

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
    AmountMode,
    CampaignStatus,
    ContributionStatus,
    ContributionType,
    PaymentStatus,
)
from app.models.membership import OrganizationMember


class ContributionCampaign(Base, TimestampMixin):
    """Une cotisation lancée auprès de membres désignés.

    « Cotisation mensuelle de fonctionnement », « Soutien mariage de M. X »,
    « Participation volontaire à la sortie » : même structure, trois natures.
    """

    __tablename__ = "contribution_campaigns"
    __table_args__ = (
        Index("ix_contribution_campaigns_org_status", "organization_id", "status"),
        Index("ix_contribution_campaigns_org_type", "organization_id", "contribution_type"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Renseigné quand la campagne se rattache au contexte d'une tontine — une
    # collecte exceptionnelle pour ses participants, par exemple. Le lien sert
    # au filtrage et aux rapports ; il ne déclenche aucune écriture de cagnotte.
    tontine_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("tontines.id", ondelete="SET NULL"), nullable=True
    )
    # Caisse destinataire des encaissements. Nulle pour une campagne de type
    # tontine, obligatoire sinon : sans destination, l'argent n'aurait nulle
    # part où aller.
    cashbox_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("cashboxes.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    contribution_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ContributionType.ASSOCIATION.value
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False, default=0)
    amount_mode: Mapped[str] = mapped_column(
        String(10), nullable=False, default=AmountMode.FIXED.value
    )
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="XOF")
    start_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    due_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    mandatory: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    penalty_enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    penalty_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=CampaignStatus.ACTIVE.value
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("organization_members.id", ondelete="SET NULL"), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    entries: Mapped[list[CampaignEntry]] = relationship(
        back_populates="campaign", cascade="all, delete-orphan"
    )

    @property
    def status_enum(self) -> CampaignStatus:
        return CampaignStatus(self.status)

    @property
    def type_enum(self) -> ContributionType:
        return ContributionType(self.contribution_type)

    @property
    def mode_enum(self) -> AmountMode:
        return AmountMode(self.amount_mode)

    @property
    def accepts_payments(self) -> bool:
        return self.status_enum.accepts_payments

    @property
    def has_expected_amount(self) -> bool:
        """Une campagne à montant libre n'a pas d'attendu — donc pas de reste."""
        return self.mode_enum is AmountMode.FIXED


class CampaignEntry(Base, TimestampMixin):
    """Ce qu'un membre désigné doit pour une campagne.

    Une ligne par membre concerné : c'est elle qui porte le suivi individuel
    — attendu, payé, reste, statut, dernier règlement. `paid_amount` est un
    cumul **dérivé** des paiements confirmés, recalculé par le service ; il ne
    se met jamais à jour tout seul, comme partout ailleurs dans le domaine.
    """

    __tablename__ = "campaign_entries"
    __table_args__ = (
        UniqueConstraint(
            "campaign_id", "member_id", name="uq_campaign_entries_campaign_id"
        ),
        Index("ix_campaign_entries_campaign_status", "campaign_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("contribution_campaigns.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # `RESTRICT` : retirer un membre ne doit pas effacer ses règlements passés.
    member_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organization_members.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    expected_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    paid_amount: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), nullable=False, default=0
    )
    due_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=ContributionStatus.PENDING.value
    )
    last_payment_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    exemption_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    campaign: Mapped[ContributionCampaign] = relationship(back_populates="entries")
    member: Mapped[OrganizationMember] = relationship()
    payments: Mapped[list[CampaignPayment]] = relationship(
        back_populates="entry",
        cascade="all, delete-orphan",
        order_by="CampaignPayment.created_at",
    )

    @property
    def status_enum(self) -> ContributionStatus:
        return ContributionStatus(self.status)

    @property
    def remaining_amount(self) -> Decimal:
        return max(Decimal("0"), self.expected_amount - self.paid_amount)

    @property
    def is_owed(self) -> bool:
        """Faux pour une ligne exemptée ou annulée : elle sort de l'attendu."""
        return self.status_enum.is_owed


class CampaignPayment(Base, TimestampMixin):
    """Un règlement reçu d'un membre pour une campagne.

    Les paiements partiels sont la norme : deux versements de 20 000 et 30 000
    restent deux lignes distinctes dans l'historique, jamais fusionnées.

    `cash_transaction_id` porte l'écriture de caisse engendrée à la
    confirmation. Le lien est ce qui interdit la double saisie : le trésorier
    confirme un paiement, il ne saisit pas en plus une entrée de caisse.
    """

    __tablename__ = "campaign_payments"
    __table_args__ = (
        Index("ix_campaign_payments_entry_status", "entry_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=new_uuid)
    organization_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entry_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("campaign_entries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    cash_transaction_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("cash_transactions.id", ondelete="SET NULL"), nullable=True
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
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancel_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    entry: Mapped[CampaignEntry] = relationship(back_populates="payments")

    @property
    def status_enum(self) -> PaymentStatus:
        return PaymentStatus(self.status)

    @property
    def counts_as_collected(self) -> bool:
        return self.status_enum.counts_as_collected
