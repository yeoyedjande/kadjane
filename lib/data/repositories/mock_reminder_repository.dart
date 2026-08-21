import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/period_label.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/notification_type.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

/// Relances simulées.
///
/// Le canal `inApp` produit une vraie notification dans l'application ; les
/// autres canaux sont marqués comme envoyés et attendent le branchement des
/// passerelles (SMS, WhatsApp, e-mail) côté backend.
///
/// TODO(api): remplacer par `RestReminderRepository` (/reminders).
class MockReminderRepository implements ReminderRepository {
  MockReminderRepository(
    this._db,
    this._audit, [
    this._dunning = const DunningService(),
  ]);

  final MockDatabase _db;
  final AuditRepository _audit;
  final DunningService _dunning;

  @override
  Future<List<DunningTarget>> targetsForCycle({
    required String tontineId,
    required String cycleId,
  }) => _db.withLatency(() => _targets(tontineId, cycleId));

  @override
  Future<List<DunningTarget>> targetsForOrganization(String organizationId) =>
      _db.withLatency(() {
        final List<DunningTarget> all = <DunningTarget>[];
        for (final Tontine tontine in _db.tontinesOf(organizationId)) {
          if (tontine.status != TontineStatus.active) {
            continue;
          }
          final TontineCycle? cycle = _openCycleOf(tontine.id);
          if (cycle == null) {
            continue;
          }
          all.addAll(_targets(tontine.id, cycle.id));
        }
        all.sort((DunningTarget a, DunningTarget b) {
          final int bySeverity = b.level.severity.compareTo(a.level.severity);
          return bySeverity != 0
              ? bySeverity
              : a.memberName.compareTo(b.memberName);
        });
        return List<DunningTarget>.unmodifiable(all);
      });

  @override
  Future<ReminderCampaignResult> sendCampaign({
    required ReminderCampaignDraft draft,
    required String actorMemberId,
  }) async {
    final ReminderCampaignResult result = await _db.withLatency(() {
      final TontineCycle cycle = _db.cycleById(draft.cycleId);
      final Tontine tontine = _db.tontineById(draft.tontineId);
      final DateTime now = DateTime.now();
      final String periodLabel = PeriodLabel.monthYear(cycle.periodStart);
      final List<DunningTarget> targets = _targets(tontine.id, cycle.id);
      final List<Reminder> created = <Reminder>[];

      final String campaignId = _db.nextId('cmp');
      double totalDue = 0;

      for (final DunningTarget target in targets) {
        final String? message = draft.messages[target.memberId];
        if (message == null) {
          continue;
        }
        totalDue += target.amountDue;
        for (final ReminderChannel channel in draft.channels) {
          final Reminder reminder = Reminder(
            id: _db.nextId('rmd'),
            organizationId: tontine.organizationId,
            tontineId: tontine.id,
            cycleId: cycle.id,
            memberId: target.memberId,
            memberName: target.memberName,
            channel: channel,
            // Les canaux externes partent en file jusqu'au branchement réel.
            status: channel.isDeliveredLocally
                ? ReminderStatus.sent
                : ReminderStatus.queued,
            level: target.level,
            message: message,
            amountDue: target.amountDue,
            dueDate: target.dueDate,
            createdAt: now,
            campaignId: campaignId,
            sentAt: channel.isDeliveredLocally ? now : null,
            sentByMemberId: actorMemberId,
            sentByName: _actorName(actorMemberId),
          );
          _db.reminders.add(reminder);
          created.add(reminder);

          if (channel.isDeliveredLocally) {
            _notify(reminder, tontine, periodLabel);
          }
        }
      }

      final ReminderCampaign campaign = ReminderCampaign(
        id: campaignId,
        organizationId: tontine.organizationId,
        tontineId: tontine.id,
        tontineName: tontine.name,
        cycleId: cycle.id,
        periodLabel: periodLabel,
        channels: List<ReminderChannel>.unmodifiable(draft.channels),
        targetCount: draft.messages.length,
        sentCount: created.where((Reminder r) => r.isDelivered).length,
        totalAmountDue: totalDue,
        createdAt: now,
        createdByMemberId: actorMemberId,
        createdByName: _actorName(actorMemberId),
      );
      _db.campaigns.add(campaign);

      return ReminderCampaignResult(campaign: campaign, reminders: created);
    });

    final Organization organization = _db.organizationById(
      result.campaign.organizationId,
    );
    await _audit.record(
      organizationId: result.campaign.organizationId,
      action: AuditAction.reminderSent,
      description:
          '${result.campaign.targetCount} relance(s) envoyée(s) pour '
          '${result.campaign.tontineName} '
          '(${result.campaign.periodLabel}) — '
          '${MoneyFormatter.format(result.campaign.totalAmountDue, organization.currency)} '
          'en attente de règlement.',
      actorMemberId: actorMemberId,
      tontineId: result.campaign.tontineId,
      targetType: 'reminder_campaign',
      targetId: result.campaign.id,
      metadata: <String, Object?>{
        'channels': result.campaign.channels
            .map((ReminderChannel c) => c.code)
            .toList(),
        'targets': result.campaign.targetCount,
      },
    );
    return result;
  }

  @override
  Future<List<ReminderCampaign>> campaignsOf(String organizationId) =>
      _db.withLatency(() {
        final List<ReminderCampaign> list =
            _db.campaigns
                .where(
                  (ReminderCampaign c) => c.organizationId == organizationId,
                )
                .toList()
              ..sort(
                (ReminderCampaign a, ReminderCampaign b) =>
                    b.createdAt.compareTo(a.createdAt),
              );
        return List<ReminderCampaign>.unmodifiable(list);
      });

  @override
  Future<List<Reminder>> forMember({
    required String organizationId,
    required String memberId,
  }) => _db.withLatency(() {
    final List<Reminder> list =
        _db.reminders
            .where(
              (Reminder r) =>
                  r.organizationId == organizationId && r.memberId == memberId,
            )
            .toList()
          ..sort(
            (Reminder a, Reminder b) => b.createdAt.compareTo(a.createdAt),
          );
    return List<Reminder>.unmodifiable(list);
  });

  @override
  Future<List<Reminder>> forCycle(String cycleId) => _db.withLatency(() {
    final List<Reminder> list = _db.remindersOfCycle(cycleId).toList()
      ..sort((Reminder a, Reminder b) => b.createdAt.compareTo(a.createdAt));
    return List<Reminder>.unmodifiable(list);
  });

  @override
  Future<void> markAsRead(String reminderId) => _db.withLatency(() {
    for (final Reminder reminder in _db.reminders) {
      if (reminder.id == reminderId && !reminder.isRead) {
        _db.replaceReminder(
          reminder.copyWith(
            status: ReminderStatus.read,
            readAt: DateTime.now(),
          ),
        );
        return;
      }
    }
  });

  // --- Interne -------------------------------------------------------------

  List<DunningTarget> _targets(String tontineId, String cycleId) {
    final Tontine tontine = _db.tontineById(tontineId);
    final TontineCycle cycle = _db.cycleById(cycleId);
    final Organization organization = _db.organizationById(
      tontine.organizationId,
    );
    return _dunning.targetsForCycle(
      tontine: tontine,
      cycle: cycle,
      settings: organization.settings,
      participants: _db.participantsOf(tontineId),
      contributions: _db.contributionsOfCycle(cycleId),
      reminders: _db.remindersOfCycle(cycleId),
    );
  }

  TontineCycle? _openCycleOf(String tontineId) {
    final DateTime now = DateTime.now();
    for (final TontineCycle cycle in _db.cyclesOf(tontineId)) {
      if (!now.isBefore(cycle.periodStart) && !now.isAfter(cycle.periodEnd)) {
        return cycle;
      }
    }
    return null;
  }

  void _notify(Reminder reminder, Tontine tontine, String periodLabel) {
    final String? userId = _userIdOfMember(reminder.memberId);
    if (userId == null) {
      return;
    }
    _db.notifications.add(
      AppNotification(
        id: _db.nextId('ntf'),
        userId: userId,
        organizationId: reminder.organizationId,
        type: reminder.level == ReminderLevel.upcoming
            ? NotificationType.contributionDue
            : NotificationType.contributionLate,
        title: '${tontine.name} · $periodLabel',
        body: reminder.message,
        createdAt: reminder.createdAt,
        data: <String, String>{
          'tontineId': reminder.tontineId,
          'cycleId': reminder.cycleId,
          'reminderId': reminder.id,
        },
      ),
    );
  }

  String? _userIdOfMember(String memberId) {
    try {
      return _db.memberById(memberId).userId;
    } on Object {
      return null;
    }
  }

  String _actorName(String memberId) {
    try {
      return _db.memberById(memberId).fullName;
    } on Object {
      return 'Système';
    }
  }
}
