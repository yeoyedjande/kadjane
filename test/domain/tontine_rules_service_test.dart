import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

void main() {
  const TontineRulesService rules = TontineRulesService();
  final DateTime periodStart = DateTime(2026, 8);

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

  TontineCycle buildCycle({double expected = 150000}) => TontineCycle(
    id: 'cyc_1',
    tontineId: 'ton_1',
    index: 1,
    periodStart: periodStart,
    periodEnd: DateTime(2026, 8, 31),
    dueDate: DateTime(2026, 8, 5),
    expectedAmount: expected,
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
    ),
    TontineParticipant(
      id: 'prt_3',
      tontineId: 'ton_1',
      memberId: 'mbr_3',
      displayName: 'Serge KOFFI',
      joinedAt: periodStart,
    ),
  ];

  Contribution contribution(
    String memberId,
    ContributionStatus status, {
    double amount = 50000,
  }) => Contribution(
    id: 'ctr_$memberId$status',
    organizationId: 'org_1',
    tontineId: 'ton_1',
    cycleId: 'cyc_1',
    memberId: memberId,
    amount: amount,
    status: status,
    recordedAt: periodStart,
    method: PaymentMethod.wave,
  );

  group('Éligibilité au tirage', () {
    test('un ancien bénéficiaire sort de la roue', () {
      final List<TontineParticipant> participants = buildParticipants();
      participants[1] = participants[1].markAsBeneficiary(
        cycleId: 'cyc_0',
        periodStart: DateTime(2026, 7),
      );

      final List<TontineParticipant> eligible = rules.eligibleForDraw(
        participants,
      );

      expect(eligible.length, 2);
      expect(
        eligible.map((TontineParticipant p) => p.id),
        isNot(contains('prt_2')),
      );
    });

    test('un ancien bénéficiaire continue de cotiser', () {
      final List<TontineParticipant> participants = buildParticipants();
      participants[1] = participants[1].markAsBeneficiary(
        cycleId: 'cyc_0',
        periodStart: DateTime(2026, 7),
      );

      final List<TontineParticipant> contributors = rules.contributors(
        participants,
      );

      expect(contributors.length, 3);
      expect(participants[1].isActive, isTrue);
      expect(participants[1].mustKeepContributing, isTrue);
      expect(participants[1].isEligibleForDraw, isFalse);
    });
  });

  group('Montants collectés', () {
    test('une cotisation annulée ne compte pas dans le collecté', () {
      final List<Contribution> contributions = <Contribution>[
        contribution('mbr_1', ContributionStatus.confirmed),
        contribution('mbr_2', ContributionStatus.cancelled),
        contribution('mbr_3', ContributionStatus.pending),
      ];

      expect(rules.collectedAmount(contributions), 50000);
      expect(rules.paidMemberIds(contributions), <String>{'mbr_1'});
    });

    test('la situation du cycle reflète les membres restants', () {
      final CycleFinancials financials = rules.financialsFor(
        tontine: buildTontine(),
        cycle: buildCycle(),
        participants: buildParticipants(),
        contributions: <Contribution>[
          contribution('mbr_1', ContributionStatus.confirmed),
          contribution('mbr_2', ContributionStatus.confirmed),
        ],
      );

      expect(financials.expected, 150000);
      expect(financials.collected, 100000);
      expect(financials.remaining, 50000);
      expect(financials.paidMembers, 2);
      expect(financials.unpaidMembers, 1);
      expect(financials.isComplete, isFalse);
    });
  });

  group('Conditions de tirage', () {
    test('bloque le tirage tant qu\'une cotisation manque', () {
      final DrawEligibility eligibility = rules.evaluateDraw(
        tontine: buildTontine(),
        cycle: buildCycle(),
        settings: const OrganizationSettings(),
        participants: buildParticipants(),
        contributions: <Contribution>[
          contribution('mbr_1', ContributionStatus.confirmed),
          contribution('mbr_2', ContributionStatus.confirmed),
        ],
      );

      expect(eligibility.allowed, isFalse);
      expect(eligibility.reason, DrawBlockReason.missingContributions);
      expect(eligibility.missingContributions, 1);
      expect(eligibility.canOverride, isTrue);
    });

    test('autorise le tirage quand tout est réglé', () {
      final DrawEligibility eligibility = rules.evaluateDraw(
        tontine: buildTontine(),
        cycle: buildCycle(),
        settings: const OrganizationSettings(),
        participants: buildParticipants(),
        contributions: <Contribution>[
          contribution('mbr_1', ContributionStatus.confirmed),
          contribution('mbr_2', ContributionStatus.confirmed),
          contribution('mbr_3', ContributionStatus.confirmed),
        ],
      );

      expect(eligibility.allowed, isTrue);
      expect(eligibility.reason, DrawBlockReason.none);
    });

    test('refuse un second tirage sur un cycle déjà attribué', () {
      final DrawEligibility eligibility = rules.evaluateDraw(
        tontine: buildTontine(),
        cycle: buildCycle().copyWith(
          status: CycleStatus.drawn,
          beneficiaryParticipantId: 'prt_1',
        ),
        settings: const OrganizationSettings(),
        participants: buildParticipants(),
        contributions: const <Contribution>[],
      );

      expect(eligibility.allowed, isFalse);
      expect(eligibility.reason, DrawBlockReason.alreadyDrawn);
    });

    test('la règle « paiement complet » peut être désactivée', () {
      final DrawEligibility eligibility = rules.evaluateDraw(
        tontine: buildTontine(),
        cycle: buildCycle(),
        settings: const OrganizationSettings(
          requireFullPaymentBeforeDraw: false,
        ),
        participants: buildParticipants(),
        contributions: const <Contribution>[],
      );

      expect(eligibility.allowed, isTrue);
    });
  });
}
