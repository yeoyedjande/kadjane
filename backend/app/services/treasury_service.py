"""Trésorerie et rapports de l'organisation.

Les montants ne sont pas ressaisis : ils sont **agrégés** depuis les
cotisations confirmées (entrées) et les versements payés (sorties), auxquels
s'ajoutent les mouvements de caisse saisis à la main (dons, frais, événements).
Une même somme n'existe donc jamais deux fois.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.errors import ValidationError
from app.models.contribution import Contribution, Payment
from app.models.dues import DuesPayment
from app.models.enums import (
    AuditAction,
    CashTransactionStatus,
    ContributionStatus,
    PaymentStatus,
    PayoutStatus,
    TontineStatus,
    TransactionCategory,
    TransactionType,
)
from app.models.membership import OrganizationMember
from app.models.payout import Beneficiary, Payout
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.models.campaign import CampaignEntry
from app.models.treasury import CashTransaction
from app.schemas import serializers as out
from app.services.audit_service import AuditService


class TreasuryService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)

    # --- Trésorerie ----------------------------------------------------------

    def snapshot(self, organization_id: uuid.UUID, *, limit: int = 50) -> dict[str, Any]:
        contributions_in = self._contributions_total(organization_id)
        dues_in = self._dues_total(organization_id)
        payouts_out = self._payouts_total(organization_id)
        manual_in, manual_out = self._manual_totals(organization_id)

        inflows = contributions_in + dues_in + manual_in
        outflows = payouts_out + manual_out

        return {
            "balance": out.money(inflows - outflows),
            "inflows": out.money(inflows),
            "outflows": out.money(outflows),
            # Détail des recettes : les cotisations de tontine transitent par
            # la cagnotte et ressortent en versements, tandis que celles de
            # caisse restent dans l'association. Les distinguer évite de lire
            # un solde flatteur.
            "contributionsTotal": out.money(contributions_in),
            "duesTotal": out.money(dues_in),
            "transactions": self.transactions(organization_id, limit=limit),
        }

    def transactions(
        self, organization_id: uuid.UUID, *, limit: int = 50
    ) -> list[dict[str, Any]]:
        """Journal unifié : cotisations, versements et mouvements manuels."""
        entries: list[dict[str, Any]] = []

        payments = self.db.scalars(
            select(Payment)
            .options(
                joinedload(Payment.contribution)
                .joinedload(Contribution.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user)
            )
            .where(
                Payment.organization_id == organization_id,
                Payment.status == PaymentStatus.CONFIRMED.value,
            )
            .order_by(Payment.paid_at.desc())
            .limit(limit)
        ).unique()
        for payment in payments:
            contribution = payment.contribution
            entries.append(
                {
                    "id": str(payment.id),
                    "organizationId": str(organization_id),
                    "type": TransactionType.INCOME.value,
                    "category": TransactionCategory.CONTRIBUTION.value,
                    "amount": out.money(payment.amount),
                    "date": out.iso(payment.paid_at or payment.created_at),
                    "createdAt": out.iso(payment.created_at),
                    "description": (
                        f"Cotisation de {contribution.participant.display_name}"
                    ),
                    "attachmentId": payment.proof_url,
                    "tontineId": str(contribution.tontine_id),
                    "createdBy": str(payment.recorded_by)
                    if payment.recorded_by
                    else None,
                    "source": "payment",
                }
            )

        payouts = self.db.scalars(
            select(Payout)
            .options(
                joinedload(Payout.beneficiary)
                .joinedload(Beneficiary.participant)
                .joinedload(TontineParticipant.member)
                .joinedload(OrganizationMember.user)
            )
            .where(
                Payout.organization_id == organization_id,
                Payout.status == PayoutStatus.PAID.value,
            )
            .order_by(Payout.paid_at.desc())
            .limit(limit)
        ).unique()
        for payout in payouts:
            entries.append(
                {
                    "id": str(payout.id),
                    "organizationId": str(organization_id),
                    "type": TransactionType.EXPENSE.value,
                    "category": TransactionCategory.PAYOUT.value,
                    "amount": out.money(payout.amount),
                    "date": out.iso(payout.paid_at or payout.created_at),
                    "createdAt": out.iso(payout.created_at),
                    "description": (
                        f"Cagnotte versée à "
                        f"{payout.beneficiary.participant.display_name}"
                    ),
                    "attachmentId": payout.proof_url,
                    "tontineId": str(payout.beneficiary.tontine_id),
                    "createdBy": str(payout.paid_by) if payout.paid_by else None,
                    "source": "payout",
                }
            )

        manual = self.db.scalars(
            select(CashTransaction)
            .where(CashTransaction.organization_id == organization_id)
            .order_by(CashTransaction.date.desc())
            .limit(limit)
        )
        entries.extend(self.serialize(transaction) for transaction in manual)

        entries.sort(key=lambda item: item["date"] or "", reverse=True)
        return entries[:limit]

    def record_transaction(
        self,
        *,
        organization_id: uuid.UUID,
        actor: OrganizationMember,
        type_: TransactionType,
        category: TransactionCategory,
        amount: Decimal,
        date: datetime | None = None,
        description: str | None = None,
        tontine_id: uuid.UUID | None = None,
        proof_url: str | None = None,
    ) -> CashTransaction:
        if amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )
        # Route historique, conservée : elle ne nomme pas de caisse, alors on
        # vise celle par défaut. Sans ce rattachement, le mouvement compterait
        # dans la trésorerie consolidée mais dans le solde d'aucune caisse.
        from app.services.cashbox_service import CashboxService

        cashbox = CashboxService(self.db).default_for(organization_id, actor=actor)
        transaction = CashTransaction(
            organization_id=organization_id,
            cashbox_id=cashbox.id,
            tontine_id=tontine_id,
            type=type_.value,
            category=category.value,
            amount=amount,
            date=date or datetime.now(timezone.utc),
            description=description,
            proof_url=proof_url,
            created_by=actor.id,
        )
        self.db.add(transaction)
        self.db.flush()

        self.audit.record(
            organization_id=organization_id,
            action=AuditAction.TRANSACTION_RECORDED,
            description=(
                f"Mouvement de caisse {type_.value} enregistré "
                f"({category.value})."
            ),
            actor=actor,
            target_type="transaction",
            target_id=transaction.id,
            tontine_id=tontine_id,
            amount=amount,
            metadata={"type": type_.value, "category": category.value},
        )
        self.db.commit()
        self.db.refresh(transaction)
        return transaction

    @staticmethod
    def serialize(transaction: CashTransaction) -> dict[str, Any]:
        return {
            "id": str(transaction.id),
            "organizationId": str(transaction.organization_id),
            "type": transaction.type,
            "category": transaction.category,
            "amount": out.money(transaction.amount),
            "date": out.iso(transaction.date),
            "createdAt": out.iso(transaction.created_at),
            "description": transaction.description,
            "attachmentId": transaction.proof_url,
            "status": transaction.status,
            "cashboxId": str(transaction.cashbox_id)
            if transaction.cashbox_id
            else None,
            "reference": transaction.reference,
            "tontineId": str(transaction.tontine_id)
            if transaction.tontine_id
            else None,
            "createdBy": str(transaction.created_by)
            if transaction.created_by
            else None,
            "source": "manual",
        }

    # --- Tableau de bord financier -------------------------------------------

    def financial_dashboard(
        self, organization_id: uuid.UUID, *, limit: int = 20
    ) -> dict[str, Any]:
        """Ce que le trésorier doit voir d'un coup d'œil.

        Attendu, encaissé et reste à encaisser sont trois nombres distincts, et
        le solde en est un quatrième : l'association peut attendre 60 000 FCFA,
        n'en avoir encaissé que 40 000, et détenir autre chose encore une fois
        les dépenses passées. Les confondre donne un tableau de bord flatteur
        et faux.
        """
        from app.services.cashbox_service import CashboxService

        cashboxes = CashboxService(self.db)
        boxes = [
            cashboxes.serialize(cashbox)
            for cashbox in cashboxes.list_for(organization_id)
        ]
        cash_balance = sum(
            (Decimal(str(box["currentBalance"])) for box in boxes), Decimal("0")
        )

        month_start = datetime.now(timezone.utc).replace(
            day=1, hour=0, minute=0, second=0, microsecond=0
        )
        month_in, month_out = self._manual_totals(organization_id, since=month_start)

        expected, collected, late = self._campaign_totals(organization_id)

        return {
            "cashBalance": out.money(cash_balance),
            "cashboxes": boxes,
            "cashboxCount": len(boxes),
            "monthInflows": out.money(month_in),
            "monthOutflows": out.money(month_out),
            # Les quatre nombres qui ne doivent jamais se confondre.
            "expected": out.money(expected),
            "collected": out.money(collected),
            "remaining": out.money(max(Decimal("0"), expected - collected)),
            "lateAmount": out.money(late),
            "recoveryRate": (
                round(float(collected / expected) * 100, 2) if expected > 0 else None
            ),
            "treasury": self.snapshot(organization_id, limit=limit),
        }

    def _campaign_totals(
        self, organization_id: uuid.UUID
    ) -> tuple[Decimal, Decimal, Decimal]:
        """Attendu, encaissé et montant en retard des campagnes de cotisation.

        Les lignes exemptées et annulées sortent de l'attendu : elles ne sont
        plus dues, et les y laisser ferait chuter un taux de recouvrement pour
        une décision qui n'a rien d'un impayé.
        """
        owed_statuses = [
            status.value
            for status in ContributionStatus
            if status.is_owed
        ]
        expected = self._decimal(
            select(func.coalesce(func.sum(CampaignEntry.expected_amount), 0)).where(
                CampaignEntry.organization_id == organization_id,
                CampaignEntry.status.in_(owed_statuses),
            )
        )
        collected = self._decimal(
            select(func.coalesce(func.sum(CampaignEntry.paid_amount), 0)).where(
                CampaignEntry.organization_id == organization_id
            )
        )
        late = self._decimal(
            select(
                func.coalesce(
                    func.sum(
                        CampaignEntry.expected_amount - CampaignEntry.paid_amount
                    ),
                    0,
                )
            ).where(
                CampaignEntry.organization_id == organization_id,
                CampaignEntry.status == ContributionStatus.LATE.value,
            )
        )
        return expected, collected, late

    # --- Rapports ------------------------------------------------------------

    def report(self, organization_id: uuid.UUID) -> dict[str, Any]:
        """Une ligne par tontine : attendu, collecté, distribué."""
        tontines = list(
            self.db.scalars(
                select(Tontine)
                .where(Tontine.organization_id == organization_id)
                .order_by(Tontine.created_at)
            )
        )

        lines: list[dict[str, Any]] = []
        total_expected = Decimal("0")
        total_collected = Decimal("0")
        total_distributed = Decimal("0")

        for tontine in tontines:
            expected = self._decimal(
                select(func.coalesce(func.sum(TontineCycle.expected_amount), 0)).where(
                    TontineCycle.tontine_id == tontine.id
                )
            )
            collected = self._decimal(
                select(func.coalesce(func.sum(TontineCycle.collected_amount), 0)).where(
                    TontineCycle.tontine_id == tontine.id
                )
            )
            distributed = self._decimal(
                select(func.coalesce(func.sum(Payout.amount), 0))
                .join(Beneficiary, Beneficiary.id == Payout.beneficiary_id)
                .where(
                    Beneficiary.tontine_id == tontine.id,
                    Payout.status == PayoutStatus.PAID.value,
                )
            )
            participants = int(
                self.db.scalar(
                    select(func.count())
                    .select_from(TontineParticipant)
                    .where(
                        TontineParticipant.tontine_id == tontine.id,
                        TontineParticipant.is_active.is_(True),
                    )
                )
                or 0
            )

            total_expected += expected
            total_collected += collected
            total_distributed += distributed
            lines.append(
                {
                    "tontineId": str(tontine.id),
                    "tontineName": tontine.name,
                    "status": tontine.status,
                    "expected": out.money(expected),
                    "collected": out.money(collected),
                    "distributed": out.money(distributed),
                    "participants": participants,
                }
            )

        members_count = int(
            self.db.scalar(
                select(func.count())
                .select_from(OrganizationMember)
                .where(OrganizationMember.organization_id == organization_id)
            )
            or 0
        )
        active = sum(1 for t in tontines if t.status == TontineStatus.ACTIVE.value)

        return {
            "totalExpected": out.money(total_expected),
            "totalCollected": out.money(total_collected),
            "totalDistributed": out.money(total_distributed),
            "membersCount": members_count,
            "activeTontines": active,
            "lines": lines,
        }

    # --- Interne -------------------------------------------------------------

    def _decimal(self, statement) -> Decimal:
        return Decimal(str(self.db.scalar(statement) or 0))

    def _contributions_total(self, organization_id: uuid.UUID) -> Decimal:
        return self._decimal(
            select(func.coalesce(func.sum(Payment.amount), 0)).where(
                Payment.organization_id == organization_id,
                Payment.status == PaymentStatus.CONFIRMED.value,
            )
        )

    def _dues_total(self, organization_id: uuid.UUID) -> Decimal:
        """Cotisations de caisse encaissées et confirmées."""
        return self._decimal(
            select(func.coalesce(func.sum(DuesPayment.amount), 0)).where(
                DuesPayment.organization_id == organization_id,
                DuesPayment.status == PaymentStatus.CONFIRMED.value,
            )
        )

    def _payouts_total(self, organization_id: uuid.UUID) -> Decimal:
        return self._decimal(
            select(func.coalesce(func.sum(Payout.amount), 0)).where(
                Payout.organization_id == organization_id,
                Payout.status == PayoutStatus.PAID.value,
            )
        )

    def _manual_totals(
        self, organization_id: uuid.UUID, *, since: datetime | None = None
    ) -> tuple[Decimal, Decimal]:
        """Entrées et sorties de caisse, annulations exclues.

        Le filtre sur le statut n'est pas une précaution : sans lui, une
        écriture annulée continuerait de peser sur le solde affiché alors
        qu'elle a disparu de celui de la caisse.
        """

        def total(type_: TransactionType) -> Decimal:
            statement = select(
                func.coalesce(func.sum(CashTransaction.amount), 0)
            ).where(
                CashTransaction.organization_id == organization_id,
                CashTransaction.type == type_.value,
                CashTransaction.status == CashTransactionStatus.CONFIRMED.value,
            )
            if since is not None:
                statement = statement.where(CashTransaction.date >= since)
            return self._decimal(statement)

        return total(TransactionType.INCOME), total(TransactionType.EXPENSE)
