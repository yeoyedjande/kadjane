"""Modèles ORM. Importer ce paquet suffit à peupler `Base.metadata`."""

from app.models.audit import AuditLog
from app.models.campaign import CampaignEntry, CampaignPayment, ContributionCampaign
from app.models.contribution import Contribution, Payment
from app.models.draw import DrawParticipant, DrawSession
from app.models.dues import DuesEntry, DuesPayment, DuesPlan
from app.models.enums import (
    AllocationMode,
    AmountMode,
    CampaignStatus,
    CashboxStatus,
    CashTransactionStatus,
    ContributionType,
    NotificationType,
    ReminderLevel,
    TransactionCategory,
    TransactionType,
    AuditAction,
    BeneficiaryStatus,
    ContributionStatus,
    CycleStatus,
    DrawStatus,
    DrawType,
    DuesPlanStatus,
    Gender,
    MemberStatus,
    OrganizationStatus,
    OrgRole,
    PaymentMethod,
    PaymentStatus,
    PayoutStatus,
    TontineFrequency,
    TontineStatus,
)
from app.models.membership import OrganizationMember
from app.models.notification import DeviceToken, Notification
from app.models.organization import Organization
from app.models.payout import Beneficiary, Payout
from app.models.rbac import Permission, Role, RolePermission
from app.models.refresh_token import RefreshToken
from app.models.reminder import Reminder, ReminderCampaign
from app.models.tontine import Tontine, TontineCycle, TontineParticipant
from app.models.treasury import Cashbox, CashTransaction
from app.models.user import User

__all__ = [
    "AllocationMode",
    "AmountMode",
    "CampaignEntry",
    "CampaignPayment",
    "CampaignStatus",
    "CashboxStatus",
    "CashTransactionStatus",
    "Cashbox",
    "CashTransaction",
    "DeviceToken",
    "Notification",
    "NotificationType",
    "ReminderLevel",
    "TransactionCategory",
    "TransactionType",
    "AuditAction",
    "AuditLog",
    "Beneficiary",
    "BeneficiaryStatus",
    "Contribution",
    "ContributionCampaign",
    "ContributionStatus",
    "ContributionType",
    "CycleStatus",
    "DrawParticipant",
    "DrawSession",
    "DrawStatus",
    "DrawType",
    "DuesEntry",
    "DuesPayment",
    "DuesPlan",
    "DuesPlanStatus",
    "Gender",
    "MemberStatus",
    "OrgRole",
    "Organization",
    "OrganizationMember",
    "OrganizationStatus",
    "Payment",
    "PaymentMethod",
    "PaymentStatus",
    "Payout",
    "PayoutStatus",
    "Permission",
    "RefreshToken",
    "Reminder",
    "Role",
    "RolePermission",
    "ReminderCampaign",
    "Tontine",
    "TontineCycle",
    "TontineFrequency",
    "TontineParticipant",
    "TontineStatus",
    "User",
]
