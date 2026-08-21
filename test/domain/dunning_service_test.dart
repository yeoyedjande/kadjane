import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/services/dunning_service.dart';

void main() {
  const DunningService service = DunningService();
  final DateTime periodStart = DateTime(2026, 8);
  final DateTime dueDate = DateTime(2026, 8, 5, 23, 59, 59);

  Tontine buildTontine() => Tontine(
    id: 'ton_1',
    organizationId: 'org_1',
    name: 'Tontine Solidarité',
    contributionAmount: 50000,
    currency: Currency.xof,
    frequency: TontineFrequency.monthly,
    allocationMode: AllocationMode.monthlyDraw,
    startDate: periodStart,
    status: TontineStatus.active,
    createdAt: periodStart,
    createdBy: 'mbr_1',
  );

  TontineCycle buildCycle() => TontineCycle(
    id: 'cyc_1',
    tontineId: 'ton_1',
    index: 1,
    periodStart: periodStart,
    periodEnd: DateTime(2026, 8, 31),
    dueDate: dueDate,
    expectedAmount: 150000,
    status: CycleStatus.collecting,
  );

  List<TontineParticipant> buildParticipants() => <TontineParticipant>[
    TontineParticipant(
      id: 'prt_1',
      tontineId: 'ton_1',
      memberId: 'mbr_1',
      displayName: 'YEO Yedjane',
      joinedAt: periodStart,
    ),
    TontineParticipant(
      id: 'prt_2',
      tontineId: 'ton_1',
      memberId: 'mbr_2',
      displayName: 'Awa KOUASSI',
      joinedAt: periodStart,
    ).markAsBeneficiary(cycleId: 'cyc_0', periodStart: DateTime(2026, 7)),
    TontineParticipant(
      id: 'prt_3',
      tontineId: 'ton_1',
      memberId: 'mbr_3',
      displayName: 'Serge KOFFI',
      joinedAt: periodStart,
    ),
  ];

  Contribution paid(String memberId) => Contribution(
    id: 'ctr_$memberId',
    organizationId: 'org_1',
    tontineId: 'ton_1',
    cycleId: 'cyc_1',
    memberId: memberId,
    amount: 50000,
    status: ContributionStatus.confirmed,
    recordedAt: periodStart,
    method: PaymentMethod.wave,
  );

  List<DunningTarget> targetsAt(
    DateTime now, {
    List<Contribution> contributions = const <Contribution>[],
    List<Reminder> reminders = const <Reminder>[],
    OrganizationSettings settings = const OrganizationSettings(),
  }) => service.targetsForCycle(
    tontine: buildTontine(),
    cycle: buildCycle(),
    settings: settings,
    participants: buildParticipants(),
    contributions: contributions,
    reminders: reminders,
    now: now,
  );

  group('Sélection des membres à relancer', () {
    test('ne relance personne trop tôt avant l\'échéance', () {
      expect(targetsAt(DateTime(2026, 7, 20)), isEmpty);
    });

    test('relance dans la fenêtre de rappel précédant l\'échéance', () {
      final List<DunningTarget> targets = targetsAt(DateTime(2026, 8, 3));

      expect(targets.length, 3);
      expect(targets.first.level, ReminderLevel.upcoming);
      expect(targets.first.daysLate, isNegative);
    });

    test('exclut les membres déjà à jour', () {
      final List<DunningTarget> targets = targetsAt(
        DateTime(2026, 8, 10),
        contributions: <Contribution>[paid('mbr_1'), paid('mbr_3')],
      );

      expect(targets.length, 1);
      expect(targets.single.memberId, 'mbr_2');
    });

    test('inclut un ancien bénéficiaire : il continue de cotiser', () {
      final List<DunningTarget> targets = targetsAt(DateTime(2026, 8, 10));

      expect(targets.map((DunningTarget t) => t.memberId), contains('mbr_2'));
    });

    test('reprend l\'historique des relances déjà envoyées', () {
      final DateTime sentAt = DateTime(2026, 8, 6, 9);
      final List<DunningTarget> targets = targetsAt(
        DateTime(2026, 8, 10),
        reminders: <Reminder>[
          Reminder(
            id: 'rmd_1',
            organizationId: 'org_1',
            tontineId: 'ton_1',
            cycleId: 'cyc_1',
            memberId: 'mbr_1',
            memberName: 'YEO Yedjane',
            channel: ReminderChannel.inApp,
            status: ReminderStatus.sent,
            level: ReminderLevel.late_,
            message: 'Merci de régulariser.',
            amountDue: 50000,
            dueDate: dueDate,
            createdAt: sentAt,
            sentAt: sentAt,
          ),
        ],
      );

      final DunningTarget yeo = targets.firstWhere(
        (DunningTarget t) => t.memberId == 'mbr_1',
      );
      expect(yeo.reminderCount, 1);
      expect(yeo.lastReminderAt, sentAt);
      expect(yeo.remindedSince(DateTime(2026, 8, 5)), isTrue);
    });
  });

  group('Niveaux d\'escalade', () {
    test('suit le retard accumulé', () {
      expect(service.levelFor(-2), ReminderLevel.upcoming);
      expect(service.levelFor(0), ReminderLevel.dueToday);
      expect(service.levelFor(3), ReminderLevel.late_);
      expect(service.levelFor(8), ReminderLevel.escalated);
    });

    test('le seuil d\'escalade est configurable', () {
      const DunningService strict = DunningService(escalationAfterDays: 2);
      expect(strict.levelFor(3), ReminderLevel.escalated);
    });

    test('trie les cibles de la plus critique à la moins urgente', () {
      final List<DunningTarget> targets = targetsAt(DateTime(2026, 8, 20));

      expect(targets.first.level, ReminderLevel.escalated);
    });
  });

  group('Composition du message', () {
    test('remplace toutes les variables du modèle', () {
      final String message = DunningService.render(
        DunningService.defaultTemplate(ReminderLevel.late_),
        memberName: 'Salif OUATTARA',
        amount: '50 000 FCFA',
        tontineName: 'Tontine Solidarité',
        periodLabel: 'Août 2026',
        dueDate: '05/08/2026',
        organizationName: 'Association Solidarité',
        daysLate: 4,
      );

      expect(message, contains('Salif OUATTARA'));
      expect(message, contains('50 000 FCFA'));
      expect(message, contains('Tontine Solidarité'));
      expect(message, contains('Août 2026'));
      expect(message, contains('4'));
      expect(message, isNot(contains('{')));
    });

    test('adapte le modèle au niveau de retard', () {
      expect(
        DunningService.defaultTemplate(ReminderLevel.upcoming),
        isNot(DunningService.defaultTemplate(ReminderLevel.escalated)),
      );
      expect(
        DunningService.defaultTemplate(ReminderLevel.escalated),
        contains('{organisation}'),
      );
    });
  });
}
