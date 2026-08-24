"""Campagnes de cotisation : de l'engagement à l'encaissement.

Le cœur du module est `record_payment`. Le trésorier saisit **une** fois
« YEO a payé 10 000 FCFA », et sept choses en découlent, dans la même
transaction :

1. le règlement est enregistré ;
2. le suivi du membre est mis à jour ;
3. le reste à payer est recalculé ;
4. le statut est recalculé ;
5. l'écriture de caisse correspondante est créée ;
6. le solde de la caisse s'en trouve modifié ;
7. l'audit garde la trace — et une notification part.

Si une seule de ces étapes échoue, aucune ne subsiste : une caisse créditée
sans règlement, ou l'inverse, serait pire qu'une erreur visible.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Iterable

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.campaign import CampaignEntry, CampaignPayment, ContributionCampaign
from app.models.enums import (
    AmountMode,
    AuditAction,
    CampaignStatus,
    ContributionStatus,
    ContributionType,
    MemberStatus,
    NotificationType,
    PaymentMethod,
    PaymentStatus,
    TransactionCategory,
    TransactionType,
)
from app.models.membership import OrganizationMember
from app.models.treasury import Cashbox
from app.schemas import serializers as out
from app.services.audit_service import AuditService
from app.services.cashbox_service import CashboxService
from app.services.notification_service import NotificationService


class CampaignService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)
        self.cashboxes = CashboxService(db)
        self.notifications = NotificationService(db)

    # --- Lecture -------------------------------------------------------------

    def list_for(
        self,
        organization_id: uuid.UUID,
        *,
        contribution_type: ContributionType | None = None,
        status: CampaignStatus | None = None,
        cashbox_id: uuid.UUID | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> tuple[list[ContributionCampaign], int]:
        statement = select(ContributionCampaign).where(
            ContributionCampaign.organization_id == organization_id
        )
        if contribution_type is not None:
            statement = statement.where(
                ContributionCampaign.contribution_type == contribution_type.value
            )
        if status is not None:
            statement = statement.where(ContributionCampaign.status == status.value)
        if cashbox_id is not None:
            statement = statement.where(
                ContributionCampaign.cashbox_id == cashbox_id
            )

        total = int(
            self.db.scalar(
                select(func.count()).select_from(statement.subquery())
            )
            or 0
        )
        rows = list(
            self.db.scalars(
                statement.order_by(ContributionCampaign.created_at.desc())
                .offset(offset)
                .limit(limit)
            )
        )
        return rows, total

    def get(
        self, organization_id: uuid.UUID, campaign_id: uuid.UUID
    ) -> ContributionCampaign:
        campaign = self.db.get(ContributionCampaign, campaign_id)
        if campaign is None or campaign.organization_id != organization_id:
            raise NotFoundError("Cotisation introuvable.", code="campaign_not_found")
        return campaign

    def entries_of(self, campaign_id: uuid.UUID) -> list[CampaignEntry]:
        return list(
            self.db.scalars(
                select(CampaignEntry)
                .options(
                    joinedload(CampaignEntry.member).joinedload(
                        OrganizationMember.user
                    )
                )
                .where(CampaignEntry.campaign_id == campaign_id)
                .order_by(CampaignEntry.created_at)
            ).unique()
        )

    def entry(self, organization_id: uuid.UUID, entry_id: uuid.UUID) -> CampaignEntry:
        entry = self.db.get(CampaignEntry, entry_id)
        if entry is None or entry.organization_id != organization_id:
            raise NotFoundError("Ligne de cotisation introuvable.", code="entry_not_found")
        return entry

    def unpaid(
        self, organization_id: uuid.UUID, *, limit: int = 100, offset: int = 0
    ) -> tuple[list[CampaignEntry], int]:
        """Impayés : ce qui reste dû, campagnes actives comprises.

        Les lignes exemptées et annulées en sont exclues — elles ne sont pas
        des impayés, elles ne sont plus attendues.
        """
        statement = (
            select(CampaignEntry)
            .options(
                joinedload(CampaignEntry.member).joinedload(OrganizationMember.user),
                joinedload(CampaignEntry.campaign),
            )
            .where(
                CampaignEntry.organization_id == organization_id,
                CampaignEntry.status.in_(
                    [
                        ContributionStatus.PENDING.value,
                        ContributionStatus.PARTIAL.value,
                        ContributionStatus.LATE.value,
                    ]
                ),
                CampaignEntry.expected_amount > CampaignEntry.paid_amount,
            )
        )
        total = int(
            self.db.scalar(select(func.count()).select_from(statement.subquery())) or 0
        )
        rows = list(
            self.db.scalars(
                statement.order_by(CampaignEntry.due_date).offset(offset).limit(limit)
            ).unique()
        )
        return rows, total

    # --- Création ------------------------------------------------------------

    def create(
        self,
        *,
        organization_id: uuid.UUID,
        actor: OrganizationMember,
        title: str,
        contribution_type: ContributionType,
        amount: Decimal,
        amount_mode: AmountMode = AmountMode.FIXED,
        description: str | None = None,
        due_date: datetime | None = None,
        start_date: datetime | None = None,
        member_ids: Iterable[uuid.UUID] | None = None,
        cashbox_id: uuid.UUID | None = None,
        tontine_id: uuid.UUID | None = None,
        mandatory: bool = True,
        penalty_enabled: bool = False,
        penalty_amount: Decimal = Decimal("0"),
        currency: str = "XOF",
    ) -> ContributionCampaign:
        if not title.strip():
            raise ValidationError("Le titre est requis.", code="campaign_title_required")
        if amount_mode is AmountMode.FIXED and amount <= 0:
            raise ValidationError(
                "Une cotisation à montant fixe demande un montant supérieur à zéro.",
                code="invalid_amount",
            )

        cashbox = self._destination(organization_id, contribution_type, cashbox_id, actor)
        campaign = ContributionCampaign(
            organization_id=organization_id,
            tontine_id=tontine_id,
            cashbox_id=cashbox.id if cashbox else None,
            title=title.strip(),
            description=description,
            contribution_type=contribution_type.value,
            amount=amount if amount_mode is AmountMode.FIXED else Decimal("0"),
            amount_mode=amount_mode.value,
            currency=currency,
            start_date=start_date,
            due_date=due_date,
            mandatory=mandatory,
            penalty_enabled=penalty_enabled,
            penalty_amount=penalty_amount,
            status=CampaignStatus.ACTIVE.value,
            created_by=actor.id,
        )
        self.db.add(campaign)
        self.db.flush()

        members = self._targets(organization_id, member_ids)
        if not members:
            raise ValidationError(
                "Aucun membre concerné : la cotisation n'aurait personne à qui s'adresser.",
                code="campaign_without_members",
            )
        for member in members:
            self.db.add(
                CampaignEntry(
                    organization_id=organization_id,
                    campaign_id=campaign.id,
                    member_id=member.id,
                    # Une campagne à montant libre n'attend rien de précis :
                    # tout versement la solde.
                    expected_amount=campaign.amount
                    if campaign.has_expected_amount
                    else Decimal("0"),
                    due_date=due_date,
                    status=ContributionStatus.PENDING.value,
                )
            )
        self.db.flush()

        self.audit.record(
            organization_id=organization_id,
            action=AuditAction.CAMPAIGN_CREATED,
            description=(
                f"Cotisation « {campaign.title} » créée pour "
                f"{len(members)} membre(s)."
            ),
            actor=actor,
            target_type="campaign",
            target_id=campaign.id,
            amount=campaign.amount * len(members) if campaign.has_expected_amount else None,
            metadata={
                "type": campaign.contribution_type,
                "amountMode": campaign.amount_mode,
                "members": len(members),
                "cashboxId": str(campaign.cashbox_id) if campaign.cashbox_id else None,
            },
        )
        self._notify_members(campaign, members)
        return campaign

    # --- Règlement -----------------------------------------------------------

    def record_payment(
        self,
        *,
        entry: CampaignEntry,
        actor: OrganizationMember,
        amount: Decimal,
        payment_method: PaymentMethod,
        reference: str | None = None,
        comment: str | None = None,
        proof_url: str | None = None,
        paid_at: datetime | None = None,
    ) -> CampaignPayment:
        """Enregistre un règlement et en tire toutes les conséquences."""
        campaign = entry.campaign
        if not campaign.accepts_payments:
            raise ConflictError(
                "Cette cotisation est close : plus aucun règlement n'y est accepté.",
                code="campaign_closed",
            )
        if entry.status_enum is ContributionStatus.EXEMPTED:
            raise ConflictError(
                "Ce membre est exempté de cette cotisation.",
                code="entry_exempted",
            )
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )
        # Le trop-perçu est refusé plutôt que rogné : c'est presque toujours une
        # faute de frappe, et un montant amputé en silence se découvre trop tard.
        if campaign.has_expected_amount and amount > entry.remaining_amount:
            raise ConflictError(
                f"Le reste à payer est de {out.money(entry.remaining_amount)}.",
                code="amount_exceeds_remaining",
                details={"remaining": out.money(entry.remaining_amount)},
            )

        when = paid_at or datetime.now(timezone.utc)
        payment = CampaignPayment(
            organization_id=entry.organization_id,
            entry_id=entry.id,
            amount=amount,
            payment_method=payment_method.value,
            reference=reference,
            comment=comment,
            proof_url=proof_url,
            status=PaymentStatus.CONFIRMED.value,
            recorded_by=actor.id,
            paid_at=when,
            confirmed_at=when,
        )
        self.db.add(payment)
        self.db.flush()

        # L'écriture de caisse : c'est elle qui fait qu'on ne saisit rien deux
        # fois. Une campagne de tontine n'en produit pas — ses fonds vont à la
        # cagnotte, pas à la caisse de l'association.
        if campaign.type_enum.feeds_cashbox:
            cashbox = self._campaign_cashbox(campaign, actor)
            transaction = self.cashboxes.record(
                cashbox=cashbox,
                actor=actor,
                type_=TransactionType.INCOME,
                category=TransactionCategory.CONTRIBUTION,
                amount=amount,
                date=when,
                description=f"{campaign.title} — {_member_name(entry)}",
                reference=reference,
                proof_url=proof_url,
                audit=False,
            )
            payment.cash_transaction_id = transaction.id

        self._refresh(entry)
        self.db.flush()

        self.audit.record(
            organization_id=entry.organization_id,
            action=AuditAction.CAMPAIGN_PAYMENT_RECORDED,
            description=(
                f"{_member_name(entry)} a réglé {out.money(amount)} "
                f"pour « {campaign.title} »."
            ),
            actor=actor,
            target_type="campaign_payment",
            target_id=payment.id,
            amount=amount,
            metadata={
                "campaignId": str(campaign.id),
                "entryId": str(entry.id),
                "method": payment_method.value,
                "status": entry.status,
            },
        )
        self._notify_payment(entry, amount)
        return payment

    def cancel_payment(
        self,
        payment: CampaignPayment,
        *,
        actor: OrganizationMember,
        reason: str | None = None,
    ) -> CampaignPayment:
        """Annule un règlement — et l'écriture de caisse qu'il avait produite."""
        if not payment.counts_as_collected:
            raise ConflictError(
                "Ce règlement est déjà annulé.", code="payment_already_cancelled"
            )
        payment.status = PaymentStatus.CANCELLED.value
        payment.cancelled_at = datetime.now(timezone.utc)
        payment.cancel_reason = reason

        if payment.cash_transaction_id is not None:
            from app.models.treasury import CashTransaction

            transaction = self.db.get(CashTransaction, payment.cash_transaction_id)
            if transaction is not None and transaction.counts_in_balance:
                self.cashboxes.cancel(
                    transaction,
                    actor=actor,
                    reason=reason or "Règlement de cotisation annulé.",
                    reversed_=True,
                )

        entry = payment.entry
        self._refresh(entry)
        self.db.flush()

        self.audit.record(
            organization_id=payment.organization_id,
            action=AuditAction.CAMPAIGN_PAYMENT_CANCELLED,
            description=(
                f"Règlement de {out.money(payment.amount)} annulé pour "
                f"{_member_name(entry)}."
            ),
            actor=actor,
            target_type="campaign_payment",
            target_id=payment.id,
            amount=payment.amount,
            metadata={"reason": reason, "entryId": str(entry.id)},
        )
        return payment

    def exempt(
        self,
        entry: CampaignEntry,
        *,
        actor: OrganizationMember,
        reason: str | None = None,
    ) -> CampaignEntry:
        """Dispense un membre : la ligne sort de l'attendu, pas de la liste."""
        if entry.paid_amount > 0:
            raise ConflictError(
                "Ce membre a déjà réglé une partie : annulez ses règlements avant "
                "de l'exempter.",
                code="entry_has_payments",
            )
        entry.status = ContributionStatus.EXEMPTED.value
        entry.exemption_reason = reason

        self.audit.record(
            organization_id=entry.organization_id,
            action=AuditAction.CAMPAIGN_MEMBER_EXEMPTED,
            description=f"{_member_name(entry)} exempté de « {entry.campaign.title} ».",
            actor=actor,
            target_type="campaign_entry",
            target_id=entry.id,
            metadata={"reason": reason},
        )
        return entry

    def close(
        self, campaign: ContributionCampaign, *, actor: OrganizationMember
    ) -> ContributionCampaign:
        campaign.status = CampaignStatus.CLOSED.value
        campaign.closed_at = datetime.now(timezone.utc)
        self.audit.record(
            organization_id=campaign.organization_id,
            action=AuditAction.CAMPAIGN_CLOSED,
            description=f"Cotisation « {campaign.title} » close.",
            actor=actor,
            target_type="campaign",
            target_id=campaign.id,
        )
        return campaign

    def refresh_late(self, organization_id: uuid.UUID) -> int:
        """Bascule en retard ce qui est échu et non soldé.

        Appelé à la lecture d'une campagne plutôt que par une tâche planifiée :
        un retard n'a d'effet que lorsqu'on le regarde, et cela évite de faire
        dépendre l'exactitude des données d'un ordonnanceur.
        """
        now = datetime.now(timezone.utc)
        changed = 0
        rows = self.db.scalars(
            select(CampaignEntry).where(
                CampaignEntry.organization_id == organization_id,
                CampaignEntry.due_date.is_not(None),
                CampaignEntry.due_date < now,
                CampaignEntry.status.in_(
                    [
                        ContributionStatus.PENDING.value,
                        ContributionStatus.PARTIAL.value,
                    ]
                ),
                CampaignEntry.expected_amount > CampaignEntry.paid_amount,
            )
        )
        for entry in rows:
            entry.status = ContributionStatus.LATE.value
            changed += 1
        if changed:
            self.db.flush()
        return changed

    # --- Agrégats ------------------------------------------------------------

    def summary(self, campaign: ContributionCampaign) -> dict[str, Any]:
        entries = self.entries_of(campaign.id)
        owed = [entry for entry in entries if entry.is_owed]
        expected = sum((entry.expected_amount for entry in owed), Decimal("0"))
        collected = sum((entry.paid_amount for entry in entries), Decimal("0"))
        remaining = max(Decimal("0"), expected - collected)

        counts = {status.value: 0 for status in ContributionStatus}
        for entry in entries:
            counts[entry.status] = counts.get(entry.status, 0) + 1

        return {
            "membersCount": len(entries),
            "expected": out.money(expected),
            "collected": out.money(collected),
            "remaining": out.money(remaining),
            # Sans attendu — campagne à montant libre — le taux n'a pas de sens :
            # `null` le dit, là où 0 % ou 100 % mentiraient tous les deux.
            "recoveryRate": (
                round(float(collected / expected) * 100, 2)
                if expected > 0
                else None
            ),
            "paidCount": counts.get(ContributionStatus.PAID.value, 0),
            "partialCount": counts.get(ContributionStatus.PARTIAL.value, 0),
            "pendingCount": counts.get(ContributionStatus.PENDING.value, 0),
            "lateCount": counts.get(ContributionStatus.LATE.value, 0),
            "exemptedCount": counts.get(ContributionStatus.EXEMPTED.value, 0),
        }

    def serialize(
        self, campaign: ContributionCampaign, *, with_summary: bool = True
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "id": str(campaign.id),
            "organizationId": str(campaign.organization_id),
            "tontineId": str(campaign.tontine_id) if campaign.tontine_id else None,
            "cashboxId": str(campaign.cashbox_id) if campaign.cashbox_id else None,
            "title": campaign.title,
            "description": campaign.description,
            "contributionType": campaign.contribution_type,
            "amount": out.money(campaign.amount),
            "amountMode": campaign.amount_mode,
            "currency": campaign.currency,
            "startDate": out.iso(campaign.start_date),
            "dueDate": out.iso(campaign.due_date),
            "mandatory": campaign.mandatory,
            "penaltyEnabled": campaign.penalty_enabled,
            "penaltyAmount": out.money(campaign.penalty_amount),
            "status": campaign.status,
            "createdBy": str(campaign.created_by) if campaign.created_by else None,
            "createdAt": out.iso(campaign.created_at),
            "updatedAt": out.iso(campaign.updated_at),
            "closedAt": out.iso(campaign.closed_at),
        }
        if with_summary:
            payload["summary"] = self.summary(campaign)
        return payload

    @staticmethod
    def serialize_entry(entry: CampaignEntry, *, with_payments: bool = False) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "id": str(entry.id),
            "organizationId": str(entry.organization_id),
            "campaignId": str(entry.campaign_id),
            "memberId": str(entry.member_id),
            "memberName": _member_name(entry),
            "expectedAmount": out.money(entry.expected_amount),
            "paidAmount": out.money(entry.paid_amount),
            "remainingAmount": out.money(entry.remaining_amount),
            "dueDate": out.iso(entry.due_date),
            "status": entry.status,
            "lastPaymentAt": out.iso(entry.last_payment_at),
            "exemptionReason": entry.exemption_reason,
            "daysLate": _days_late(entry),
        }
        if with_payments:
            payload["payments"] = [
                CampaignService.serialize_payment(payment) for payment in entry.payments
            ]
        return payload

    @staticmethod
    def serialize_payment(payment: CampaignPayment) -> dict[str, Any]:
        return {
            "id": str(payment.id),
            "organizationId": str(payment.organization_id),
            "entryId": str(payment.entry_id),
            "cashTransactionId": str(payment.cash_transaction_id)
            if payment.cash_transaction_id
            else None,
            "amount": out.money(payment.amount),
            "paymentMethod": payment.payment_method,
            "reference": payment.reference,
            "comment": payment.comment,
            "attachmentId": payment.proof_url,
            "status": payment.status,
            "recordedBy": str(payment.recorded_by) if payment.recorded_by else None,
            "paidAt": out.iso(payment.paid_at),
            "confirmedAt": out.iso(payment.confirmed_at),
            "cancelledAt": out.iso(payment.cancelled_at),
            "cancelReason": payment.cancel_reason,
        }

    # --- Interne -------------------------------------------------------------

    def _refresh(self, entry: CampaignEntry) -> None:
        """Recalcule le cumul réglé et le statut depuis les paiements confirmés.

        Dérivé, jamais incrémenté : annuler un règlement remet le compte juste
        sans arithmétique inverse, qui finit toujours par dériver.
        """
        total = Decimal(
            str(
                self.db.scalar(
                    select(func.coalesce(func.sum(CampaignPayment.amount), 0)).where(
                        CampaignPayment.entry_id == entry.id,
                        CampaignPayment.status == PaymentStatus.CONFIRMED.value,
                    )
                )
                or 0
            )
        )
        entry.paid_amount = total
        last = self.db.scalar(
            select(func.max(CampaignPayment.paid_at)).where(
                CampaignPayment.entry_id == entry.id,
                CampaignPayment.status == PaymentStatus.CONFIRMED.value,
            )
        )
        entry.last_payment_at = last

        if entry.status_enum in {
            ContributionStatus.EXEMPTED,
            ContributionStatus.CANCELLED,
        }:
            return

        campaign = entry.campaign
        if not campaign.has_expected_amount:
            # Montant libre : tout versement solde la ligne.
            entry.status = (
                ContributionStatus.PAID.value
                if total > 0
                else ContributionStatus.PENDING.value
            )
            return

        if total >= entry.expected_amount:
            entry.status = ContributionStatus.PAID.value
        elif _is_overdue(entry):
            # Le retard prime sur le partiel : c'est le retard qui appelle une
            # relance, et un règlement incomplet ne le fait pas disparaître.
            entry.status = ContributionStatus.LATE.value
        elif total > 0:
            entry.status = ContributionStatus.PARTIAL.value
        else:
            entry.status = ContributionStatus.PENDING.value

    def _targets(
        self, organization_id: uuid.UUID, member_ids: Iterable[uuid.UUID] | None
    ) -> list[OrganizationMember]:
        """Membres concernés : la sélection, ou tous les actifs à défaut."""
        statement = select(OrganizationMember).where(
            OrganizationMember.organization_id == organization_id
        )
        if member_ids is not None:
            wanted = list(member_ids)
            if not wanted:
                return []
            statement = statement.where(OrganizationMember.id.in_(wanted))
        else:
            statement = statement.where(
                OrganizationMember.status == MemberStatus.ACTIVE.value
            )
        return list(self.db.scalars(statement))

    def _destination(
        self,
        organization_id: uuid.UUID,
        contribution_type: ContributionType,
        cashbox_id: uuid.UUID | None,
        actor: OrganizationMember,
    ) -> Cashbox | None:
        if not contribution_type.feeds_cashbox:
            return None
        if cashbox_id is not None:
            cashbox = self.cashboxes.get(organization_id, cashbox_id)
            if not cashbox.accepts_transactions:
                raise ConflictError(
                    "Cette caisse est fermée : elle ne peut pas recevoir de cotisation.",
                    code="cashbox_closed",
                )
            return cashbox
        return self.cashboxes.default_for(organization_id, actor=actor)

    def _campaign_cashbox(
        self, campaign: ContributionCampaign, actor: OrganizationMember
    ) -> Cashbox:
        if campaign.cashbox_id is not None:
            return self.cashboxes.get(campaign.organization_id, campaign.cashbox_id)
        return self.cashboxes.default_for(campaign.organization_id, actor=actor)

    def _notify_members(
        self, campaign: ContributionCampaign, members: list[OrganizationMember]
    ) -> None:
        deadline = (
            f" Échéance : {campaign.due_date.strftime('%d/%m/%Y')}."
            if campaign.due_date
            else ""
        )
        headline = (
            f"Une nouvelle cotisation de {out.money(campaign.amount)} "
            f"{campaign.currency} a été créée."
            if campaign.has_expected_amount
            else "Une nouvelle cotisation à montant libre a été créée."
        )
        for member in members:
            self.notifications.notify(
                user_id=member.user_id,
                type_=NotificationType.CONTRIBUTION_DUE,
                title=campaign.title,
                body=headline + deadline,
                organization_id=campaign.organization_id,
                target_route="/my-dues",
                data={"campaignId": str(campaign.id)},
            )

    def _notify_payment(self, entry: CampaignEntry, amount: Decimal) -> None:
        settled = entry.status_enum is ContributionStatus.PAID
        self.notifications.notify(
            user_id=entry.member.user_id,
            type_=NotificationType.PAYMENT_CONFIRMED,
            title=entry.campaign.title,
            body=(
                "Votre cotisation est entièrement réglée. Merci."
                if settled
                else f"Votre paiement de {out.money(amount)} a été enregistré. "
                f"Reste à payer : {out.money(entry.remaining_amount)}."
            ),
            organization_id=entry.organization_id,
            target_route="/my-dues",
            data={"campaignId": str(entry.campaign_id)},
        )


def _member_name(entry: CampaignEntry) -> str:
    member = entry.member
    if member is None or member.user is None:
        return "Membre"
    return member.user.full_name


def _aware(value: datetime) -> datetime:
    """SQLite rend des dates naïves : les comparer lèverait une `TypeError`."""
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _is_overdue(entry: CampaignEntry) -> bool:
    return (
        entry.due_date is not None
        and _aware(entry.due_date) < datetime.now(timezone.utc)
    )


def _days_late(entry: CampaignEntry) -> int:
    if not _is_overdue(entry) or not entry.is_owed:
        return 0
    if entry.expected_amount <= entry.paid_amount:
        return 0
    return (datetime.now(timezone.utc) - _aware(entry.due_date)).days
