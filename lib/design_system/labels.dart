import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/domain/enums/draw_enums.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/notification_type.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Traduction des énumérations métier.
///
/// Le domaine ne connaît pas l'interface : la correspondance
/// « valeur métier → libellé traduit » vit ici, au même endroit pour toute
/// l'application.
class Labels {
  const Labels._();

  static String role(AppLocalizations l10n, OrgRole role) {
    switch (role) {
      case OrgRole.superAdmin:
        return l10n.roleSuperAdmin;
      case OrgRole.admin:
        return l10n.roleAdmin;
      case OrgRole.president:
        return l10n.rolePresident;
      case OrgRole.treasurer:
        return l10n.roleTreasurer;
      case OrgRole.auditor:
        return l10n.roleAuditor;
      case OrgRole.member:
        return l10n.roleMember;
    }
  }

  static String memberStatus(AppLocalizations l10n, MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return l10n.statusActive;
      case MemberStatus.inactive:
        return l10n.statusInactive;
      case MemberStatus.suspended:
        return l10n.statusSuspended;
      case MemberStatus.pending:
        return l10n.statusPending;
    }
  }

  static String gender(AppLocalizations l10n, Gender gender) {
    switch (gender) {
      case Gender.male:
        return l10n.membersMale;
      case Gender.female:
        return l10n.membersFemale;
      case Gender.unspecified:
        return l10n.commonNone;
    }
  }

  static String tontineStatus(AppLocalizations l10n, TontineStatus status) {
    switch (status) {
      case TontineStatus.draft:
        return l10n.tontineStatusDraft;
      case TontineStatus.pending:
        return l10n.tontineStatusPending;
      case TontineStatus.active:
        return l10n.tontineStatusActive;
      case TontineStatus.suspended:
        return l10n.tontineStatusSuspended;
      case TontineStatus.completed:
        return l10n.tontineStatusCompleted;
      case TontineStatus.cancelled:
        return l10n.tontineStatusCancelled;
    }
  }

  static String frequency(AppLocalizations l10n, TontineFrequency frequency) {
    switch (frequency) {
      case TontineFrequency.weekly:
        return l10n.frequencyWeekly;
      case TontineFrequency.biweekly:
        return l10n.frequencyBiweekly;
      case TontineFrequency.monthly:
        return l10n.frequencyMonthly;
      case TontineFrequency.custom:
        return l10n.frequencyCustom;
    }
  }

  static String allocationMode(AppLocalizations l10n, AllocationMode mode) {
    switch (mode) {
      case AllocationMode.monthlyDraw:
        return l10n.allocationMonthlyDraw;
      case AllocationMode.fullOrderDraw:
        return l10n.allocationFullOrder;
      case AllocationMode.manualOrder:
        return l10n.allocationManualOrder;
    }
  }

  static String allocationModeDescription(
    AppLocalizations l10n,
    AllocationMode mode,
  ) {
    switch (mode) {
      case AllocationMode.monthlyDraw:
        return l10n.allocationMonthlyDrawDesc;
      case AllocationMode.fullOrderDraw:
        return l10n.allocationFullOrderDesc;
      case AllocationMode.manualOrder:
        return l10n.allocationManualOrderDesc;
    }
  }

  static String contributionStatus(
    AppLocalizations l10n,
    ContributionStatus status,
  ) {
    switch (status) {
      case ContributionStatus.pending:
        return l10n.paymentStatusPending;
      case ContributionStatus.confirmed:
        return l10n.paymentStatusConfirmed;
      case ContributionStatus.rejected:
        return l10n.paymentStatusRejected;
      case ContributionStatus.cancelled:
        return l10n.paymentStatusCancelled;
    }
  }

  static String paymentMethod(AppLocalizations l10n, PaymentMethod method) {
    switch (method) {
      case PaymentMethod.wave:
        return l10n.methodWave;
      case PaymentMethod.orangeMoney:
        return l10n.methodOrangeMoney;
      case PaymentMethod.mtnMomo:
        return l10n.methodMtnMomo;
      case PaymentMethod.moovMoney:
        return l10n.methodMoovMoney;
      case PaymentMethod.bankTransfer:
        return l10n.methodBankTransfer;
      case PaymentMethod.cash:
        return l10n.methodCash;
      case PaymentMethod.other:
        return l10n.methodOther;
    }
  }

  static String payoutStatus(AppLocalizations l10n, PayoutStatus status) {
    switch (status) {
      case PayoutStatus.pending:
        return l10n.payoutStatusPending;
      case PayoutStatus.processing:
        return l10n.payoutStatusProcessing;
      case PayoutStatus.paid:
        return l10n.payoutStatusPaid;
      case PayoutStatus.failed:
        return l10n.payoutStatusFailed;
    }
  }

  static String drawStatus(AppLocalizations l10n, DrawStatus status) {
    switch (status) {
      case DrawStatus.scheduled:
        return l10n.drawStatusScheduled;
      case DrawStatus.completed:
        return l10n.drawStatusCompleted;
      case DrawStatus.cancelled:
        return l10n.drawStatusCancelled;
      case DrawStatus.invalidated:
        return l10n.drawStatusInvalidated;
    }
  }

  static String transactionType(AppLocalizations l10n, TransactionType type) =>
      type == TransactionType.income
      ? l10n.treasuryIncome
      : l10n.treasuryExpense;

  static IconData notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.contributionDue:
        return Icons.event_available_outlined;
      case NotificationType.contributionLate:
        return Icons.warning_amber_outlined;
      case NotificationType.paymentConfirmed:
        return Icons.check_circle_outline;
      case NotificationType.drawScheduled:
        return Icons.schedule_outlined;
      case NotificationType.drawResult:
        return Icons.celebration_outlined;
      case NotificationType.potComplete:
        return Icons.savings_outlined;
      case NotificationType.payoutDone:
        return Icons.payments_outlined;
      case NotificationType.newMember:
        return Icons.person_add_alt_outlined;
      case NotificationType.announcement:
        return Icons.campaign_outlined;
    }
  }

  static String reminderChannel(AppLocalizations l10n, ReminderChannel c) {
    switch (c) {
      case ReminderChannel.inApp:
        return l10n.remindersChannelInApp;
      case ReminderChannel.push:
        return l10n.remindersChannelPush;
      case ReminderChannel.sms:
        return l10n.remindersChannelSms;
      case ReminderChannel.whatsapp:
        return l10n.remindersChannelWhatsapp;
      case ReminderChannel.email:
        return l10n.remindersChannelEmail;
    }
  }

  static IconData reminderChannelIcon(ReminderChannel c) {
    switch (c) {
      case ReminderChannel.inApp:
        return Icons.notifications_active_outlined;
      case ReminderChannel.push:
        return Icons.mobile_friendly_outlined;
      case ReminderChannel.sms:
        return Icons.sms_outlined;
      case ReminderChannel.whatsapp:
        return Icons.chat_outlined;
      case ReminderChannel.email:
        return Icons.mail_outline;
    }
  }

  static String reminderLevel(AppLocalizations l10n, ReminderLevel level) {
    switch (level) {
      case ReminderLevel.upcoming:
        return l10n.remindersLevelUpcoming;
      case ReminderLevel.dueToday:
        return l10n.remindersLevelDueToday;
      case ReminderLevel.late_:
        return l10n.remindersLevelLate;
      case ReminderLevel.escalated:
        return l10n.remindersLevelEscalated;
    }
  }

  static String reminderStatus(AppLocalizations l10n, ReminderStatus status) {
    switch (status) {
      case ReminderStatus.queued:
        return l10n.remindersStatusQueued;
      case ReminderStatus.sent:
        return l10n.remindersStatusSent;
      case ReminderStatus.read:
        return l10n.remindersStatusRead;
      case ReminderStatus.failed:
        return l10n.remindersStatusFailed;
    }
  }

  /// Module d'une permission, dérivé de son code (`member.create` -> Membres).
  static String permissionModule(AppLocalizations l10n, String moduleCode) {
    switch (moduleCode) {
      case 'organization':
        return l10n.permModuleOrganization;
      case 'member':
        return l10n.permModuleMember;
      case 'tontine':
        return l10n.permModuleTontine;
      case 'contribution':
        return l10n.permModuleContribution;
      case 'draw':
        return l10n.permModuleDraw;
      case 'payout':
        return l10n.permModulePayout;
      case 'treasury':
        return l10n.permModuleTreasury;
      case 'reminder':
        return l10n.permModuleReminder;
      case 'report':
        return l10n.permModuleReport;
      default:
        return l10n.permModuleAudit;
    }
  }

  /// Action d'une permission (`member.create` -> Créer).
  static String permissionAction(AppLocalizations l10n, Permission p) {
    switch (p.code.split('.').last) {
      case 'view':
        return l10n.permActionView;
      case 'edit':
        return l10n.permActionEdit;
      case 'create':
        return l10n.permActionCreate;
      case 'manage_officers':
        return l10n.permActionManageOfficers;
      case 'invite':
        return l10n.permActionInvite;
      case 'validate':
        return l10n.permActionValidate;
      case 'record':
        return l10n.permActionRecord;
      case 'confirm':
        return l10n.permActionConfirm;
      case 'cancel':
        return l10n.permActionCancel;
      case 'run':
        return l10n.permActionRun;
      case 'override':
        return l10n.permActionOverride;
      case 'invalidate':
        return l10n.permActionInvalidate;
      case 'send':
        return l10n.permActionSend;
      default:
        return l10n.permActionManage;
    }
  }

  /// Permissions regroupées par module, dans l'ordre de déclaration.
  static Map<String, List<Permission>> permissionsByModule() {
    final Map<String, List<Permission>> grouped = <String, List<Permission>>{};
    for (final Permission p in Permission.values) {
      grouped.putIfAbsent(p.code.split('.').first, () => <Permission>[]).add(p);
    }
    return grouped;
  }

  static IconData paymentIcon(PaymentMethod method) {
    if (method.isMobileMoney) {
      return Icons.smartphone_outlined;
    }
    switch (method) {
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      default:
        return Icons.more_horiz;
    }
  }
}

/// Couleurs associées à un état (badge, pastille, bordure).
class StatusTone {
  const StatusTone(this.foreground, this.background);

  final Color foreground;
  final Color background;

  static StatusTone contribution(
    KadjaneColors colors,
    ContributionStatus status,
  ) {
    switch (status) {
      case ContributionStatus.confirmed:
        return StatusTone(colors.success, colors.successSurface);
      case ContributionStatus.pending:
        return StatusTone(colors.warning, colors.warningSurface);
      case ContributionStatus.rejected:
      case ContributionStatus.cancelled:
        return StatusTone(colors.danger, colors.dangerSurface);
    }
  }

  static StatusTone tontine(KadjaneColors colors, TontineStatus status) {
    switch (status) {
      case TontineStatus.active:
        return StatusTone(colors.success, colors.successSurface);
      case TontineStatus.pending:
      case TontineStatus.draft:
        return StatusTone(colors.textSecondary, colors.surfaceMuted);
      case TontineStatus.suspended:
        return StatusTone(colors.warning, colors.warningSurface);
      case TontineStatus.completed:
        return StatusTone(colors.info, colors.infoSurface);
      case TontineStatus.cancelled:
        return StatusTone(colors.danger, colors.dangerSurface);
    }
  }

  static StatusTone payout(KadjaneColors colors, PayoutStatus status) {
    switch (status) {
      case PayoutStatus.paid:
        return StatusTone(colors.success, colors.successSurface);
      case PayoutStatus.processing:
        return StatusTone(colors.info, colors.infoSurface);
      case PayoutStatus.pending:
        return StatusTone(colors.warning, colors.warningSurface);
      case PayoutStatus.failed:
        return StatusTone(colors.danger, colors.dangerSurface);
    }
  }

  static StatusTone draw(KadjaneColors colors, DrawStatus status) {
    switch (status) {
      case DrawStatus.completed:
        return StatusTone(colors.success, colors.successSurface);
      case DrawStatus.scheduled:
        return StatusTone(colors.info, colors.infoSurface);
      case DrawStatus.cancelled:
      case DrawStatus.invalidated:
        return StatusTone(colors.danger, colors.dangerSurface);
    }
  }

  static StatusTone member(KadjaneColors colors, MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return StatusTone(colors.success, colors.successSurface);
      case MemberStatus.pending:
        return StatusTone(colors.warning, colors.warningSurface);
      case MemberStatus.inactive:
        return StatusTone(colors.textSecondary, colors.surfaceMuted);
      case MemberStatus.suspended:
        return StatusTone(colors.danger, colors.dangerSurface);
    }
  }
}

/// Fabriques de tons, à partir de la palette du thème.
///
/// Vit ici, aux côtés de [StatusTone] : ces couleurs relèvent du design
/// system, pas d'un écran en particulier.
class StatusToneHelper {
  const StatusToneHelper._();

  static StatusTone neutral(BuildContext context) =>
      StatusTone(context.colors.textSecondary, context.colors.surfaceMuted);

  static StatusTone success(BuildContext context) =>
      StatusTone(context.colors.success, context.colors.successSurface);

  static StatusTone warning(BuildContext context) =>
      StatusTone(context.colors.warning, context.colors.warningSurface);

  static StatusTone danger(BuildContext context) =>
      StatusTone(context.colors.danger, context.colors.dangerSurface);

  static StatusTone info(BuildContext context) =>
      StatusTone(context.colors.info, context.colors.infoSurface);
}
