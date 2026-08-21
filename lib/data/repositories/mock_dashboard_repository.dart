import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Agrégations du dashboard, calculées à partir de la base mock.
///
/// TODO(api): remplacer par un unique appel backend (/dashboard) afin
/// d'éviter les agrégations côté client.
class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository(
    this._db, [
    this._rules = const TontineRulesService(),
  ]);

  final MockDatabase _db;
  final TontineRulesService _rules;

  static const int _trendLength = 6;

  @override
  Future<DashboardSnapshot> load({
    required String organizationId,
    required String memberId,
  }) => _db.withLatency(() {
    final Organization organization = _db.organizationById(organizationId);
    final List<Tontine> active = _db
        .tontinesOf(organizationId)
        .where((Tontine t) => t.status == TontineStatus.active)
        .toList(growable: false);

    double expected = 0;
    double collected = 0;
    int late = 0;
    double myDue = 0;
    double myPaid = 0;
    final List<UpcomingDeadline> deadlines = <UpcomingDeadline>[];
    final Map<DateTime, List<double>> trendBuckets = <DateTime, List<double>>{};
    UpcomingDraw? nextDraw;

    for (final Tontine tontine in active) {
      final List<TontineParticipant> participants = _db.participantsOf(
        tontine.id,
      );
      final List<TontineCycle> cycles = _db.cyclesOf(tontine.id);
      final TontineCycle? current = _currentCycle(cycles);

      for (final TontineCycle cycle in cycles) {
        if (cycle.periodStart.isAfter(DateTime.now())) {
          continue;
        }
        final DateTime key = DateTime(
          cycle.periodStart.year,
          cycle.periodStart.month,
        );
        final List<double> bucket = trendBuckets.putIfAbsent(
          key,
          () => <double>[0, 0],
        );
        bucket[0] += cycle.expectedAmount;
        bucket[1] += _rules.collectedAmount(_db.contributionsOfCycle(cycle.id));
      }

      if (current == null) {
        continue;
      }
      final List<Contribution> contributions = _db.contributionsOfCycle(
        current.id,
      );
      final CycleFinancials financials = _rules.financialsFor(
        tontine: tontine,
        cycle: current,
        participants: participants,
        contributions: contributions,
      );
      expected += financials.expected;
      collected += financials.collected;
      late += _rules
          .lateParticipants(
            cycle: current,
            participants: participants,
            contributions: contributions,
            settings: organization.settings,
          )
          .length;

      final TontineParticipant? me = _rules.participantOf(
        participants,
        memberId,
      );
      if (me != null) {
        myDue += tontine.contributionAmount;
        final bool paid = contributions.any(
          (Contribution c) => c.memberId == memberId && c.countsAsCollected,
        );
        if (paid) {
          myPaid += tontine.contributionAmount;
        }
        deadlines.add(
          UpcomingDeadline(
            tontineId: tontine.id,
            tontineName: tontine.name,
            cycleId: current.id,
            periodStart: current.periodStart,
            dueDate: current.dueDate,
            amount: tontine.contributionAmount,
            isPaid: paid,
          ),
        );
      }

      if (!tontine.allocationMode.hasPredefinedOrder &&
          !current.hasBeneficiary) {
        final DrawEligibility eligibility = _rules.evaluateDraw(
          tontine: tontine,
          cycle: current,
          settings: organization.settings,
          participants: participants,
          contributions: contributions,
        );
        final UpcomingDraw candidate = UpcomingDraw(
          tontineId: tontine.id,
          tontineName: tontine.name,
          cycleId: current.id,
          periodStart: current.periodStart,
          scheduledAt: current.drawScheduledAt ?? current.dueDate,
          eligibleCount: _rules.eligibleForDraw(participants).length,
          potAmount: current.expectedAmount,
          isUnlocked: eligibility.allowed,
        );
        if (nextDraw == null ||
            candidate.scheduledAt.isBefore(nextDraw.scheduledAt)) {
          nextDraw = candidate;
        }
      }
    }

    deadlines.sort(
      (UpcomingDeadline a, UpcomingDeadline b) =>
          a.dueDate.compareTo(b.dueDate),
    );

    final List<DateTime> keys = trendBuckets.keys.toList()
      ..sort((DateTime a, DateTime b) => a.compareTo(b));
    final List<TrendPoint> trend = keys
        .skip(keys.length > _trendLength ? keys.length - _trendLength : 0)
        .map(
          (DateTime key) => TrendPoint(
            periodStart: key,
            expected: trendBuckets[key]![0],
            collected: trendBuckets[key]![1],
          ),
        )
        .toList(growable: false);

    final List<AuditLog> recent =
        _db.auditLogs
            .where((AuditLog log) => log.organizationId == organizationId)
            .toList()
          ..sort(
            (AuditLog a, AuditLog b) => b.createdAt.compareTo(a.createdAt),
          );

    return DashboardSnapshot(
      organization: organization,
      membersCount: _db.membersOf(organizationId).length,
      activeTontines: active.length,
      expectedThisPeriod: expected,
      collectedThisPeriod: collected,
      lateContributions: late,
      myContributionDue: myDue,
      myContributionPaid: myPaid,
      deadlines: deadlines.take(5).toList(growable: false),
      recentActivity: recent.take(5).toList(growable: false),
      trend: trend,
      nextDraw: nextDraw,
      currentBeneficiary: _currentBeneficiary(organizationId),
    );
  });

  TontineCycle? _currentCycle(List<TontineCycle> cycles) {
    if (cycles.isEmpty) {
      return null;
    }
    final DateTime now = DateTime.now();
    for (final TontineCycle cycle in cycles) {
      if (!now.isBefore(cycle.periodStart) && !now.isAfter(cycle.periodEnd)) {
        return cycle;
      }
    }
    for (final TontineCycle cycle in cycles) {
      if (cycle.status != CycleStatus.closed) {
        return cycle;
      }
    }
    return null;
  }

  CurrentBeneficiaryView? _currentBeneficiary(String organizationId) {
    final List<Beneficiary> list =
        _db.beneficiaries
            .where((Beneficiary b) => b.organizationId == organizationId)
            .toList()
          ..sort(
            (Beneficiary a, Beneficiary b) =>
                b.designatedAt.compareTo(a.designatedAt),
          );
    if (list.isEmpty) {
      return null;
    }
    final Beneficiary beneficiary = list.first;
    final Payout? payout = _db.payoutOfCycle(beneficiary.cycleId);
    final TontineCycle cycle = _db.cycleById(beneficiary.cycleId);
    return CurrentBeneficiaryView(
      tontineId: beneficiary.tontineId,
      tontineName: _db.tontineById(beneficiary.tontineId).name,
      cycleId: beneficiary.cycleId,
      memberName: beneficiary.memberName,
      avatarUrl: beneficiary.avatarUrl,
      amount: beneficiary.amount,
      periodStart: cycle.periodStart,
      isPaidOut: payout?.isPaid ?? false,
    );
  }
}
