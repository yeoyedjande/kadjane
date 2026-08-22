"""Énumérations métier partagées.

Les valeurs sont exactement les `code` attendus par l'application Flutter
(`lib/domain/enums/`) : aucune conversion n'est nécessaire côté client.
"""

from __future__ import annotations

from enum import StrEnum


class OrgRole(StrEnum):
    """Rôles dans une organisation, du plus fort au plus faible.

    TODO(roles): migrer vers un vrai système Role/Permission persisté
    (tables `roles` et `role_permissions`) quand la console d'administration
    devra créer des rôles sur mesure. Les permissions par défaut vivent déjà
    dans `app/services/permission_service.py`, prêtes à être surchargées.
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
    """Statut de la ligne attendue d'un participant pour un cycle."""

    PENDING = "pending"
    PARTIAL = "partial"
    PAID = "paid"
    LATE = "late"
    CANCELLED = "cancelled"


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


class TransactionType(StrEnum):
    INCOME = "income"
    EXPENSE = "expense"


class TransactionCategory(StrEnum):
    CONTRIBUTION = "contribution"
    PAYOUT = "payout"
    DONATION = "donation"
    FEE = "fee"
    EVENT = "event"
    SOCIAL_AID = "social_aid"
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
