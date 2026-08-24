"""Énumérations métier partagées.

Les valeurs sont exactement les `code` attendus par l'application Flutter
(`lib/domain/enums/`) : aucune conversion n'est nécessaire côté client.
"""

from __future__ import annotations

from enum import StrEnum


class OrgRole(StrEnum):
    """Rôles système d'une organisation, du plus fort au plus faible.

    Ces valeurs restent l'**étiquette** du membre : elles portent la hiérarchie
    (`level`), donc l'anti-escalade lors d'un changement de rôle. Les droits,
    eux, viennent des tables `roles` / `role_permissions` — un membre peut
    porter un rôle personnalisé qui n'a pas d'équivalent ici.
    """

    SUPER_ADMIN = "super_admin"
    ORGANIZATION_ADMIN = "admin"
    PRESIDENT = "president"
    TREASURER = "treasurer"
    AUDITOR = "auditor"
    MEMBER = "member"

    @property
    def level(self) -> int:
        return _ROLE_LEVELS[self]

    @property
    def is_officer(self) -> bool:
        return self.level >= OrgRole.AUDITOR.level


_ROLE_LEVELS: dict[OrgRole, int] = {
    OrgRole.SUPER_ADMIN: 100,
    OrgRole.ORGANIZATION_ADMIN: 80,
    OrgRole.PRESIDENT: 70,
    OrgRole.TREASURER: 60,
    OrgRole.AUDITOR: 40,
    OrgRole.MEMBER: 10,
}


class MemberStatus(StrEnum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    PENDING = "pending"


class OrganizationStatus(StrEnum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    ARCHIVED = "archived"


class Gender(StrEnum):
    MALE = "male"
    FEMALE = "female"
    UNSPECIFIED = "unspecified"


# --- Métier tontine ---------------------------------------------------------
# Les valeurs sont les `code` de `lib/domain/enums/` : le client les lit tels
# quels. Les noms de membres suivent la nomenclature du cahier des charges
# (MONTHLY_DRAW…), les valeurs restent en snake_case pour l'API.


class TontineStatus(StrEnum):
    DRAFT = "draft"
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class TontineFrequency(StrEnum):
    WEEKLY = "weekly"
    BIWEEKLY = "biweekly"
    MONTHLY = "monthly"
    CUSTOM = "custom"


class DuesPlanStatus(StrEnum):
    """Cycle de vie d'un plan de cotisation de caisse."""

    ACTIVE = "active"
    # Suspendu : plus aucune échéance n'est engendrée, les impayés subsistent.
    PAUSED = "paused"
    CLOSED = "closed"


class AllocationMode(StrEnum):
    MONTHLY_DRAW = "monthly_draw"
    FULL_ORDER_DRAW = "full_order_draw"
    MANUAL_ORDER = "manual_order"

    @property
    def has_predefined_order(self) -> bool:
        return self is not AllocationMode.MONTHLY_DRAW


class CycleStatus(StrEnum):
    UPCOMING = "upcoming"
    COLLECTING = "collecting"
    READY_FOR_DRAW = "ready_for_draw"
    DRAWN = "drawn"
    PAID_OUT = "paid_out"
    CLOSED = "closed"


class ContributionStatus(StrEnum):
    """Statut d'une ligne attendue : cycle de tontine, caisse ou campagne.

    `EXEMPTED` dispense un membre d'une campagne sans fausser le taux de
    recouvrement : la ligne sort de l'attendu au lieu de rester impayée.
    """

    PENDING = "pending"
    PARTIAL = "partial"
    PAID = "paid"
    LATE = "late"
    EXEMPTED = "exempted"
    CANCELLED = "cancelled"

    @property
    def is_owed(self) -> bool:
        """Vrai si la ligne pèse encore sur l'attendu."""
        return self not in {
            ContributionStatus.EXEMPTED,
            ContributionStatus.CANCELLED,
        }


class PaymentStatus(StrEnum):
    """Statut d'un versement de cotisation.

    Seul `CONFIRMED` compte dans les montants collectés.
    """

    PENDING = "pending"
    CONFIRMED = "confirmed"
    REJECTED = "rejected"
    CANCELLED = "cancelled"

    @property
    def counts_as_collected(self) -> bool:
        return self is PaymentStatus.CONFIRMED


class ContributionType(StrEnum):
    """Nature d'une cotisation — elle décide d'où va l'argent.

    `TONTINE` ne passe **pas** par les campagnes : ces cotisations vivent dans
    `contributions`, alimentent la cagnotte du cycle et ne touchent jamais la
    caisse de l'association. La valeur existe pour que les rapports puissent
    nommer les quatre natures d'un même vocabulaire.
    """

    TONTINE = "tontine"
    ASSOCIATION = "association"
    EXCEPTIONAL = "exceptional"
    VOLUNTARY = "voluntary"

    @property
    def feeds_cashbox(self) -> bool:
        return self is not ContributionType.TONTINE


class AmountMode(StrEnum):
    """`FREE` : chacun donne ce qu'il veut — l'attendu n'a pas de sens."""

    FIXED = "fixed"
    FREE = "free"


class CampaignStatus(StrEnum):
    DRAFT = "draft"
    ACTIVE = "active"
    CLOSED = "closed"
    CANCELLED = "cancelled"

    @property
    def accepts_payments(self) -> bool:
        return self is CampaignStatus.ACTIVE


class RoleStatus(StrEnum):
    ACTIVE = "active"
    DISABLED = "disabled"


class PaymentMethod(StrEnum):
    CASH = "cash"
    WAVE = "wave"
    ORANGE_MONEY = "orange_money"
    MTN_MOMO = "mtn_momo"
    MOOV_MONEY = "moov_money"
    BANK_TRANSFER = "bank_transfer"
    OTHER = "other"


class DrawStatus(StrEnum):
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    INVALIDATED = "invalidated"


class DrawType(StrEnum):
    PERIODIC = "periodic_draw"
    FULL_ORDER = "order_draw"
    MANUAL = "manual_order"


class BeneficiaryStatus(StrEnum):
    DESIGNATED = "designated"
    PAYOUT_PENDING = "payout_pending"
    PAID = "paid"
    CANCELLED = "cancelled"


class PayoutStatus(StrEnum):
    """Statuts du contrat client. `CONFIRMED` du cahier des charges ≡ `PAID`."""

    PENDING = "pending"
    PROCESSING = "processing"
    PAID = "paid"
    FAILED = "failed"


class AuditAction(StrEnum):
    MEMBER_CREATED = "member.created"
    MEMBER_UPDATED = "member.updated"
    MEMBER_ROLE_CHANGED = "member.role_changed"
    TONTINE_CREATED = "tontine.created"
    TONTINE_UPDATED = "tontine.updated"
    TONTINE_STATUS_CHANGED = "tontine.status_changed"
    CONTRIBUTION_RECORDED = "contribution.recorded"
    CONTRIBUTION_CONFIRMED = "contribution.confirmed"
    CONTRIBUTION_CANCELLED = "contribution.cancelled"
    DRAW_SCHEDULED = "draw.scheduled"
    DRAW_COMPLETED = "draw.completed"
    DRAW_OVERRIDDEN = "draw.overridden"
    DRAW_CANCELLED = "draw.cancelled"
    DRAW_INVALIDATED = "draw.invalidated"
    ORDER_GENERATED = "order.generated"
    BENEFICIARY_DESIGNATED = "beneficiary.designated"
    PAYOUT_RECORDED = "payout.recorded"
    PAYOUT_CONFIRMED = "payout.confirmed"
    TRANSACTION_RECORDED = "transaction.recorded"
    DUES_PLAN_CREATED = "dues.plan_created"
    DUES_PLAN_UPDATED = "dues.plan_updated"
    DUES_PAYMENT_RECORDED = "dues.payment_recorded"
    DUES_PAYMENT_CANCELLED = "dues.payment_cancelled"
    REMINDER_SENT = "reminder.sent"
    ORGANIZATION_UPDATED = "organization.updated"
    CASHBOX_CREATED = "cashbox.created"
    CASHBOX_UPDATED = "cashbox.updated"
    CASHBOX_CLOSED = "cashbox.closed"
    TRANSACTION_CANCELLED = "transaction.cancelled"
    CAMPAIGN_CREATED = "campaign.created"
    CAMPAIGN_UPDATED = "campaign.updated"
    CAMPAIGN_CLOSED = "campaign.closed"
    CAMPAIGN_PAYMENT_RECORDED = "campaign.payment_recorded"
    CAMPAIGN_PAYMENT_CANCELLED = "campaign.payment_cancelled"
    CAMPAIGN_MEMBER_EXEMPTED = "campaign.member_exempted"
    ROLE_CREATED = "role.created"
    ROLE_UPDATED = "role.updated"
    ROLE_PERMISSIONS_CHANGED = "role.permissions_changed"


class TransactionType(StrEnum):
    INCOME = "income"
    EXPENSE = "expense"
    # Mouvement entre deux caisses de la même organisation : la sortie de
    # l'une et l'entrée de l'autre sont deux lignes, pour que chaque caisse
    # garde un journal lisible.
    TRANSFER = "transfer"
    # Correction d'écart constatée à l'inventaire. Signée : le montant peut
    # être négatif, contrairement aux autres types.
    ADJUSTMENT = "adjustment"

    @property
    def direction(self) -> int:
        """Signe du mouvement sur le solde : +1, -1, ou 0 si porté par le montant."""
        if self is TransactionType.INCOME:
            return 1
        if self is TransactionType.EXPENSE or self is TransactionType.TRANSFER:
            return -1
        return 0


class CashTransactionStatus(StrEnum):
    """Une écriture financière ne se supprime pas — elle change d'état.

    `CANCELLED` annule une saisie erronée, `REVERSED` contrepasse une écriture
    valide. Ni l'une ni l'autre ne compte dans le solde ; les deux restent
    dans le journal et dans l'audit.
    """

    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    REVERSED = "reversed"

    @property
    def counts_in_balance(self) -> bool:
        return self is CashTransactionStatus.CONFIRMED


class CashboxStatus(StrEnum):
    OPEN = "open"
    CLOSED = "closed"
    SUSPENDED = "suspended"

    @property
    def accepts_transactions(self) -> bool:
        return self is CashboxStatus.OPEN


class TransactionCategory(StrEnum):
    CONTRIBUTION = "contribution"
    PAYOUT = "payout"
    DONATION = "donation"
    FEE = "fee"
    EVENT = "event"
    SOCIAL_AID = "social_aid"
    PENALTY = "penalty"
    REFUND = "refund"
    ADMINISTRATIVE = "administrative"
    TRANSFER = "transfer"
    OTHER = "other"


class NotificationType(StrEnum):
    CONTRIBUTION_DUE = "contribution_due"
    CONTRIBUTION_LATE = "contribution_late"
    PAYMENT_CONFIRMED = "payment_confirmed"
    DRAW_SCHEDULED = "draw_scheduled"
    DRAW_RESULT = "draw_result"
    POT_COMPLETE = "pot_complete"
    PAYOUT_DONE = "payout_done"
    NEW_MEMBER = "new_member"
    ANNOUNCEMENT = "announcement"


class ReminderChannel(StrEnum):
    """Canaux de relance. Codes alignés sur `lib/domain/enums/reminder_enums.dart`."""

    IN_APP = "in_app"
    PUSH = "push"
    SMS = "sms"
    WHATSAPP = "whatsapp"
    EMAIL = "email"


class ReminderLevel(StrEnum):
    UPCOMING = "upcoming"
    DUE_TODAY = "due_today"
    LATE = "late"
    ESCALATED = "escalated"
