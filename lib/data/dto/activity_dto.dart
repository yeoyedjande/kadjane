import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/data/dto/organization_dto.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/notification_type.dart';
import 'package:kadjane/domain/enums/transaction_enums.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/repositories/report_repository.dart';
import 'package:kadjane/domain/repositories/treasury_repository.dart';

class AppNotificationDto {
  const AppNotificationDto._();

  static AppNotification fromJson(JsonMap json) => AppNotification(
    id: Json.string(json, 'id'),
    userId: Json.stringOr(json, 'userId'),
    type: NotificationType.fromCode(
      Json.stringOr(json, 'type', 'announcement'),
    ),
    title: Json.stringOr(json, 'title'),
    body: Json.stringOr(json, 'body'),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    organizationId: Json.stringOrNull(json, 'organizationId'),
    readAt: Json.dateOrNull(json, 'readAt'),
    targetRoute: Json.stringOrNull(json, 'targetRoute'),
    data: Json.stringMap(json, 'data'),
  );
}

class AuditLogDto {
  const AuditLogDto._();

  static AuditLog fromJson(JsonMap json) => AuditLog(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    action: AuditAction.fromCode(
      Json.stringOr(json, 'action', 'organization.updated'),
    ),
    description: Json.stringOr(json, 'description'),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    actorMemberId: Json.stringOrNull(json, 'actorMemberId'),
    actorName: Json.stringOr(json, 'actorName', 'Système'),
    targetType: Json.stringOrNull(json, 'targetType'),
    targetId: Json.stringOrNull(json, 'targetId'),
    tontineId: Json.stringOrNull(json, 'tontineId'),
    amount: json['amount'] == null ? null : Json.amount(json, 'amount'),
    metadata: Json.rawMap(json, 'metadata'),
  );
}

class CashTransactionDto {
  const CashTransactionDto._();

  static CashTransaction fromJson(JsonMap json) => CashTransaction(
    id: Json.string(json, 'id'),
    organizationId: Json.stringOr(json, 'organizationId'),
    type: TransactionType.fromCode(Json.stringOr(json, 'type', 'income')),
    category: TransactionCategory.fromCode(
      Json.stringOr(json, 'category', 'other'),
    ),
    amount: Json.amount(json, 'amount'),
    date: Json.dateOrNull(json, 'date') ?? DateTime.now(),
    createdAt: Json.dateOrNull(json, 'createdAt') ?? DateTime.now(),
    description: Json.stringOrNull(json, 'description'),
    attachmentId: Json.stringOrNull(json, 'attachmentId'),
    tontineId: Json.stringOrNull(json, 'tontineId'),
    createdBy: Json.stringOrNull(json, 'createdBy'),
  );

  static JsonMap draftToJson(TransactionDraft draft) => <String, dynamic>{
    'type': draft.type.code,
    'category': draft.category.code,
    'amount': draft.amount,
    'date': Json.iso(draft.date),
    'description': draft.description,
    'attachmentId': draft.attachmentId,
    'tontineId': draft.tontineId,
  };
}

class TreasurySnapshotDto {
  const TreasurySnapshotDto._();

  static TreasurySnapshot fromJson(JsonMap json) => TreasurySnapshot(
    balance: Json.amount(json, 'balance'),
    inflows: Json.amount(json, 'inflows'),
    outflows: Json.amount(json, 'outflows'),
    transactions: Json.objects(
      json,
      'transactions',
    ).map(CashTransactionDto.fromJson).toList(growable: false),
  );
}

class DashboardSnapshotDto {
  const DashboardSnapshotDto._();

  static DashboardSnapshot fromJson(JsonMap json) => DashboardSnapshot(
    organization: OrganizationDto.fromJson(Json.object(json, 'organization')),
    membersCount: Json.integer(json, 'membersCount'),
    activeTontines: Json.integer(json, 'activeTontines'),
    expectedThisPeriod: Json.amount(json, 'expectedThisPeriod'),
    collectedThisPeriod: Json.amount(json, 'collectedThisPeriod'),
    lateContributions: Json.integer(json, 'lateContributions'),
    myContributionDue: Json.amount(json, 'myContributionDue'),
    myContributionPaid: Json.amount(json, 'myContributionPaid'),
    deadlines: Json.objects(
      json,
      'deadlines',
    ).map(_deadline).toList(growable: false),
    recentActivity: Json.objects(
      json,
      'recentActivity',
    ).map(AuditLogDto.fromJson).toList(growable: false),
    trend: Json.objects(json, 'trend').map(_trend).toList(growable: false),
    nextDraw: Json.objectOrNull(json, 'nextDraw') == null
        ? null
        : _nextDraw(Json.object(json, 'nextDraw')),
    currentBeneficiary: Json.objectOrNull(json, 'currentBeneficiary') == null
        ? null
        : _currentBeneficiary(Json.object(json, 'currentBeneficiary')),
  );

  static UpcomingDeadline _deadline(JsonMap json) => UpcomingDeadline(
    tontineId: Json.stringOr(json, 'tontineId'),
    tontineName: Json.stringOr(json, 'tontineName'),
    cycleId: Json.stringOr(json, 'cycleId'),
    periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
    dueDate: Json.dateOrNull(json, 'dueDate') ?? DateTime.now(),
    amount: Json.amount(json, 'amount'),
    isPaid: Json.boolean(json, 'isPaid'),
  );

  static TrendPoint _trend(JsonMap json) => TrendPoint(
    periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
    collected: Json.amount(json, 'collected'),
    expected: Json.amount(json, 'expected'),
  );

  static UpcomingDraw _nextDraw(JsonMap json) => UpcomingDraw(
    tontineId: Json.stringOr(json, 'tontineId'),
    tontineName: Json.stringOr(json, 'tontineName'),
    cycleId: Json.stringOr(json, 'cycleId'),
    periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
    scheduledAt: Json.dateOrNull(json, 'scheduledAt') ?? DateTime.now(),
    eligibleCount: Json.integer(json, 'eligibleCount'),
    potAmount: Json.amount(json, 'potAmount'),
    isUnlocked: Json.boolean(json, 'isUnlocked'),
  );

  static CurrentBeneficiaryView _currentBeneficiary(JsonMap json) =>
      CurrentBeneficiaryView(
        tontineId: Json.stringOr(json, 'tontineId'),
        tontineName: Json.stringOr(json, 'tontineName'),
        cycleId: Json.stringOr(json, 'cycleId'),
        memberName: Json.stringOr(json, 'memberName'),
        amount: Json.amount(json, 'amount'),
        periodStart: Json.dateOrNull(json, 'periodStart') ?? DateTime.now(),
        isPaidOut: Json.boolean(json, 'isPaidOut'),
        avatarUrl: Json.stringOrNull(json, 'avatarUrl'),
      );
}

class ReportSnapshotDto {
  const ReportSnapshotDto._();

  static ReportSnapshot fromJson(JsonMap json) => ReportSnapshot(
    totalExpected: Json.amount(json, 'totalExpected'),
    totalCollected: Json.amount(json, 'totalCollected'),
    totalDistributed: Json.amount(json, 'totalDistributed'),
    membersCount: Json.integer(json, 'membersCount'),
    activeTontines: Json.integer(json, 'activeTontines'),
    lines: Json.objects(json, 'lines').map(_line).toList(growable: false),
  );

  static TontineReportLine _line(JsonMap json) => TontineReportLine(
    tontineId: Json.stringOr(json, 'tontineId'),
    tontineName: Json.stringOr(json, 'tontineName'),
    expected: Json.amount(json, 'expected'),
    collected: Json.amount(json, 'collected'),
    distributed: Json.amount(json, 'distributed'),
    participants: Json.integer(json, 'participants'),
  );
}
