import 'package:kadjane/domain/enums/reminder_enums.dart';

/// Relance adressée à un membre pour une cotisation non réglée.
///
/// Une relance n'est jamais supprimée : elle constitue la preuve que le membre
/// a bien été sollicité avant toute mesure (blocage de tirage, pénalité...).
class Reminder {
  const Reminder({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.cycleId,
    required this.memberId,
    required this.memberName,
    required this.channel,
    required this.status,
    required this.level,
    required this.message,
    required this.amountDue,
    required this.dueDate,
    required this.createdAt,
    this.campaignId,
    this.sentAt,
    this.readAt,
    this.sentByMemberId,
    this.sentByName,
    this.failureReason,
  });

  final String id;
  final String organizationId;
  final String tontineId;
  final String cycleId;
  final String memberId;
  final String memberName;
  final ReminderChannel channel;
  final ReminderStatus status;
  final ReminderLevel level;

  /// Message réellement envoyé, figé au moment de l'envoi.
  final String message;
  final double amountDue;
  final DateTime dueDate;

  /// Campagne d'origine (envoi groupé).
  final String? campaignId;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final String? sentByMemberId;
  final String? sentByName;
  final String? failureReason;

  bool get isRead => readAt != null;

  bool get isDelivered =>
      status == ReminderStatus.sent || status == ReminderStatus.read;

  Reminder copyWith({
    ReminderStatus? status,
    DateTime? sentAt,
    DateTime? readAt,
    String? failureReason,
  }) => Reminder(
    id: id,
    organizationId: organizationId,
    tontineId: tontineId,
    cycleId: cycleId,
    memberId: memberId,
    memberName: memberName,
    channel: channel,
    status: status ?? this.status,
    level: level,
    message: message,
    amountDue: amountDue,
    dueDate: dueDate,
    createdAt: createdAt,
    campaignId: campaignId,
    sentAt: sentAt ?? this.sentAt,
    readAt: readAt ?? this.readAt,
    sentByMemberId: sentByMemberId,
    sentByName: sentByName,
    failureReason: failureReason ?? this.failureReason,
  );
}

/// Envoi groupé de relances sur une période donnée.
class ReminderCampaign {
  const ReminderCampaign({
    required this.id,
    required this.organizationId,
    required this.tontineId,
    required this.tontineName,
    required this.cycleId,
    required this.periodLabel,
    required this.channels,
    required this.targetCount,
    required this.sentCount,
    required this.createdAt,
    this.createdByMemberId,
    this.createdByName,
    this.totalAmountDue = 0,
  });

  final String id;
  final String organizationId;
  final String tontineId;
  final String tontineName;
  final String cycleId;
  final String periodLabel;
  final List<ReminderChannel> channels;
  final int targetCount;
  final int sentCount;
  final double totalAmountDue;
  final DateTime createdAt;
  final String? createdByMemberId;
  final String? createdByName;

  bool get isComplete => sentCount >= targetCount && targetCount > 0;
}
