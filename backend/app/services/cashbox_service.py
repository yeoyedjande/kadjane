"""Caisses : ouverture, mouvements, soldes.

Le solde d'une caisse n'est jamais stocké. Il se recompose :

    solde = solde d'ouverture
          + entrées confirmées
          - sorties confirmées

Les écritures annulées ou contrepassées n'y entrent pas, mais restent dans le
journal. Une somme financière ne se supprime pas : elle change d'état, et
l'audit garde la trace de qui l'a changée.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.enums import (
    AuditAction,
    CashboxStatus,
    CashTransactionStatus,
    TransactionCategory,
    TransactionType,
)
from app.models.membership import OrganizationMember
from app.models.treasury import Cashbox, CashTransaction
from app.schemas import serializers as out
from app.services.audit_service import AuditService

DEFAULT_CASHBOX_NAME = "Caisse principale"


class CashboxService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.audit = AuditService(db)

    # --- Lecture -------------------------------------------------------------

    def list_for(self, organization_id: uuid.UUID) -> list[Cashbox]:
        return list(
            self.db.scalars(
                select(Cashbox)
                .where(Cashbox.organization_id == organization_id)
                .order_by(Cashbox.is_default.desc(), Cashbox.name)
            )
        )

    def get(self, organization_id: uuid.UUID, cashbox_id: uuid.UUID) -> Cashbox:
        cashbox = self.db.get(Cashbox, cashbox_id)
        # Une caisse d'une autre organisation est traitée comme inexistante :
        # répondre 403 confirmerait son existence.
        if cashbox is None or cashbox.organization_id != organization_id:
            raise NotFoundError("Caisse introuvable.", code="cashbox_not_found")
        return cashbox

    def balance(self, cashbox: Cashbox) -> Decimal:
        movements = self._sum_signed(cashbox.id)
        return Decimal(str(cashbox.opening_balance)) + movements

    def default_for(
        self, organization_id: uuid.UUID, *, actor: OrganizationMember | None = None
    ) -> Cashbox:
        """Caisse destinataire par défaut, créée à la volée si nécessaire.

        Une organisation qui n'a jamais ouvert de caisse doit pouvoir encaisser
        sans passer d'abord par un formulaire : la « Caisse principale » naît
        au premier encaissement.
        """
        existing = self.db.scalars(
            select(Cashbox)
            .where(
                Cashbox.organization_id == organization_id,
                Cashbox.status == CashboxStatus.OPEN.value,
            )
            .order_by(Cashbox.is_default.desc(), Cashbox.created_at)
        ).first()
        if existing is not None:
            return existing
        return self.create(
            organization_id=organization_id,
            actor=actor,
            name=DEFAULT_CASHBOX_NAME,
            description="Caisse créée automatiquement au premier encaissement.",
            is_default=True,
        )

    # --- Écriture ------------------------------------------------------------

    def create(
        self,
        *,
        organization_id: uuid.UUID,
        actor: OrganizationMember | None,
        name: str,
        description: str | None = None,
        currency: str = "XOF",
        opening_balance: Decimal = Decimal("0"),
        is_default: bool = False,
    ) -> Cashbox:
        clean = name.strip()
        if not clean:
            raise ValidationError("Le nom de la caisse est requis.", code="cashbox_name_required")
        if self._name_taken(organization_id, clean):
            raise ConflictError(
                "Une caisse porte déjà ce nom dans cette association.",
                code="cashbox_name_taken",
            )
        if opening_balance < 0:
            raise ValidationError(
                "Le solde d'ouverture ne peut pas être négatif.",
                code="invalid_opening_balance",
            )

        if is_default:
            self._clear_default(organization_id)
        cashbox = Cashbox(
            organization_id=organization_id,
            name=clean,
            description=description,
            currency=currency,
            opening_balance=opening_balance,
            status=CashboxStatus.OPEN.value,
            is_default=is_default or not self.list_for(organization_id),
            created_by=actor.id if actor else None,
        )
        self.db.add(cashbox)
        self.db.flush()

        self.audit.record(
            organization_id=organization_id,
            action=AuditAction.CASHBOX_CREATED,
            description=f"Caisse « {cashbox.name} » ouverte.",
            actor=actor,
            target_type="cashbox",
            target_id=cashbox.id,
            amount=opening_balance or None,
            metadata={"currency": currency, "openingBalance": str(opening_balance)},
        )
        return cashbox

    def update(
        self,
        cashbox: Cashbox,
        *,
        actor: OrganizationMember,
        name: str | None = None,
        description: str | None = None,
        is_default: bool | None = None,
    ) -> Cashbox:
        changes: dict[str, Any] = {}
        if name is not None and name.strip() and name.strip() != cashbox.name:
            clean = name.strip()
            if self._name_taken(cashbox.organization_id, clean, exclude=cashbox.id):
                raise ConflictError(
                    "Une caisse porte déjà ce nom dans cette association.",
                    code="cashbox_name_taken",
                )
            changes["name"] = clean
            cashbox.name = clean
        if description is not None:
            cashbox.description = description
        if is_default:
            self._clear_default(cashbox.organization_id)
            cashbox.is_default = True
            changes["isDefault"] = True

        self.audit.record(
            organization_id=cashbox.organization_id,
            action=AuditAction.CASHBOX_UPDATED,
            description=f"Caisse « {cashbox.name} » modifiée.",
            actor=actor,
            target_type="cashbox",
            target_id=cashbox.id,
            metadata=changes,
        )
        return cashbox

    def close(self, cashbox: Cashbox, *, actor: OrganizationMember) -> Cashbox:
        """Clôt une caisse : elle n'accepte plus de mouvement.

        Le solde résiduel n'est pas remis à zéro — le fermer ne fait pas
        disparaître l'argent. Il reste lisible, et un transfert vers une autre
        caisse est la façon correcte de le vider.
        """
        if cashbox.status == CashboxStatus.CLOSED.value:
            return cashbox
        cashbox.status = CashboxStatus.CLOSED.value
        cashbox.closed_at = datetime.now(timezone.utc)
        cashbox.is_default = False

        self.audit.record(
            organization_id=cashbox.organization_id,
            action=AuditAction.CASHBOX_CLOSED,
            description=f"Caisse « {cashbox.name} » fermée.",
            actor=actor,
            target_type="cashbox",
            target_id=cashbox.id,
            amount=self.balance(cashbox),
            metadata={"residualBalance": str(self.balance(cashbox))},
        )
        return cashbox

    def record(
        self,
        *,
        cashbox: Cashbox,
        actor: OrganizationMember | None,
        type_: TransactionType,
        category: TransactionCategory,
        amount: Decimal,
        date: datetime | None = None,
        description: str | None = None,
        reference: str | None = None,
        proof_url: str | None = None,
        tontine_id: uuid.UUID | None = None,
        audit: bool = True,
    ) -> CashTransaction:
        """Pose une écriture dans une caisse.

        `audit=False` pour une écriture engendrée par un règlement de campagne :
        le paiement produit déjà sa propre trace, et en écrire deux ferait lire
        deux opérations là où le trésorier n'en a fait qu'une.
        """
        if not cashbox.accepts_transactions:
            raise ConflictError(
                "Cette caisse est fermée : aucun mouvement ne peut y être enregistré.",
                code="cashbox_closed",
            )
        # Seul l'ajustement porte son signe : il corrige un écart d'inventaire,
        # dans un sens ou dans l'autre.
        if type_ is TransactionType.ADJUSTMENT:
            if amount == 0:
                raise ValidationError(
                    "Un ajustement de zéro n'a pas d'effet.", code="invalid_amount"
                )
        elif amount <= 0:
            raise ValidationError(
                "Le montant doit être supérieur à zéro.", code="invalid_amount"
            )

        transaction = CashTransaction(
            organization_id=cashbox.organization_id,
            cashbox_id=cashbox.id,
            tontine_id=tontine_id,
            type=type_.value,
            category=category.value,
            status=CashTransactionStatus.CONFIRMED.value,
            amount=amount,
            date=date or datetime.now(timezone.utc),
            description=description,
            reference=reference,
            proof_url=proof_url,
            created_by=actor.id if actor else None,
        )
        self.db.add(transaction)
        self.db.flush()

        if audit:
            self.audit.record(
                organization_id=cashbox.organization_id,
                action=AuditAction.TRANSACTION_RECORDED,
                description=(
                    f"{_label(type_)} de {out.money(abs(amount))} "
                    f"dans « {cashbox.name} » ({category.value})."
                ),
                actor=actor,
                target_type="transaction",
                target_id=transaction.id,
                tontine_id=tontine_id,
                amount=abs(amount),
                metadata={
                    "type": type_.value,
                    "category": category.value,
                    "cashboxId": str(cashbox.id),
                },
            )
        return transaction

    def cancel(
        self,
        transaction: CashTransaction,
        *,
        actor: OrganizationMember,
        reason: str | None = None,
        reversed_: bool = False,
    ) -> CashTransaction:
        """Sort une écriture du solde sans la sortir du journal."""
        if not transaction.counts_in_balance:
            raise ConflictError(
                "Ce mouvement est déjà annulé.", code="transaction_already_cancelled"
            )
        transaction.status = (
            CashTransactionStatus.REVERSED.value
            if reversed_
            else CashTransactionStatus.CANCELLED.value
        )
        transaction.cancelled_at = datetime.now(timezone.utc)
        transaction.cancel_reason = reason

        self.audit.record(
            organization_id=transaction.organization_id,
            action=AuditAction.TRANSACTION_CANCELLED,
            description=(
                f"Mouvement de {out.money(abs(transaction.amount))} "
                f"{'contrepassé' if reversed_ else 'annulé'}."
            ),
            actor=actor,
            target_type="transaction",
            target_id=transaction.id,
            amount=abs(transaction.amount),
            metadata={"reason": reason, "status": transaction.status},
        )
        return transaction

    # --- Sérialisation -------------------------------------------------------

    def serialize(self, cashbox: Cashbox) -> dict[str, Any]:
        inflows, outflows = self._flows(cashbox.id)
        return {
            "id": str(cashbox.id),
            "organizationId": str(cashbox.organization_id),
            "name": cashbox.name,
            "description": cashbox.description,
            "currency": cashbox.currency,
            "openingBalance": out.money(cashbox.opening_balance),
            "currentBalance": out.money(self.balance(cashbox)),
            "inflows": out.money(inflows),
            "outflows": out.money(outflows),
            "status": cashbox.status,
            "isDefault": cashbox.is_default,
            "createdBy": str(cashbox.created_by) if cashbox.created_by else None,
            "createdAt": out.iso(cashbox.created_at),
            "updatedAt": out.iso(cashbox.updated_at),
            "closedAt": out.iso(cashbox.closed_at),
        }

    @staticmethod
    def serialize_transaction(transaction: CashTransaction) -> dict[str, Any]:
        return {
            "id": str(transaction.id),
            "organizationId": str(transaction.organization_id),
            "cashboxId": str(transaction.cashbox_id)
            if transaction.cashbox_id
            else None,
            "type": transaction.type,
            "category": transaction.category,
            "status": transaction.status,
            "amount": out.money(transaction.amount),
            "date": out.iso(transaction.date),
            "createdAt": out.iso(transaction.created_at),
            "description": transaction.description,
            "reference": transaction.reference,
            "attachmentId": transaction.proof_url,
            "tontineId": str(transaction.tontine_id)
            if transaction.tontine_id
            else None,
            "createdBy": str(transaction.created_by)
            if transaction.created_by
            else None,
            "cancelledAt": out.iso(transaction.cancelled_at),
            "cancelReason": transaction.cancel_reason,
            "source": "manual",
        }

    # --- Interne -------------------------------------------------------------

    def _name_taken(
        self, organization_id: uuid.UUID, name: str, *, exclude: uuid.UUID | None = None
    ) -> bool:
        statement = select(func.count()).select_from(Cashbox).where(
            Cashbox.organization_id == organization_id,
            func.lower(Cashbox.name) == name.lower(),
        )
        if exclude is not None:
            statement = statement.where(Cashbox.id != exclude)
        return bool(self.db.scalar(statement))

    def _clear_default(self, organization_id: uuid.UUID) -> None:
        for other in self.db.scalars(
            select(Cashbox).where(
                Cashbox.organization_id == organization_id,
                Cashbox.is_default.is_(True),
            )
        ):
            other.is_default = False

    def _sum_signed(self, cashbox_id: uuid.UUID) -> Decimal:
        inflows, outflows = self._flows(cashbox_id)
        return inflows - outflows

    def _flows(self, cashbox_id: uuid.UUID) -> tuple[Decimal, Decimal]:
        """Entrées et sorties confirmées d'une caisse.

        L'ajustement est ventilé selon le signe de son montant : positif il
        crédite, négatif il débite.
        """
        rows = self.db.execute(
            select(
                CashTransaction.type,
                func.coalesce(func.sum(CashTransaction.amount), 0),
            )
            .where(
                CashTransaction.cashbox_id == cashbox_id,
                CashTransaction.status == CashTransactionStatus.CONFIRMED.value,
                CashTransaction.amount >= 0,
            )
            .group_by(CashTransaction.type)
        )
        inflows = Decimal("0")
        outflows = Decimal("0")
        for type_value, total in rows:
            amount = Decimal(str(total or 0))
            direction = TransactionType(type_value).direction
            if direction > 0 or (direction == 0):
                inflows += amount
            else:
                outflows += amount

        negative_adjustments = Decimal(
            str(
                self.db.scalar(
                    select(func.coalesce(func.sum(CashTransaction.amount), 0)).where(
                        CashTransaction.cashbox_id == cashbox_id,
                        CashTransaction.status
                        == CashTransactionStatus.CONFIRMED.value,
                        CashTransaction.amount < 0,
                    )
                )
                or 0
            )
        )
        outflows += -negative_adjustments
        return inflows, outflows


def _label(type_: TransactionType) -> str:
    return {
        TransactionType.INCOME: "Entrée",
        TransactionType.EXPENSE: "Sortie",
        TransactionType.TRANSFER: "Transfert",
        TransactionType.ADJUSTMENT: "Ajustement",
    }[type_]
