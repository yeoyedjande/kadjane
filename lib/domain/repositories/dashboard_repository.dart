import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/organization.dart';

/// Échéance à venir affichée sur le dashboard.
class UpcomingDeadline {
  const UpcomingDeadline({
    required this.tontineId,
    required this.tontineName,
    required this.cycleId,
    required this.periodStart,
    required this.dueDate,
    required this.amount,
    required this.isPaid,
  });

  final String tontineId;
  final String tontineName;
  final String cycleId;
  final DateTime periodStart;
  final DateTime dueDate;
  final double amount;
  final bool isPaid;

  bool get isLate => !isPaid && DateTime.now().isAfter(dueDate);
}

/// Prochain tirage connu de l'organisation.
class UpcomingDraw {
  const UpcomingDraw({
    required this.tontineId,
    required this.tontineName,
    required this.cycleId,
    required this.periodStart,
    required this.scheduledAt,
    required this.eligibleCount,
    required this.potAmount,
    required this.isUnlocked,
  });

  final String tontineId;
  final String tontineName;
  final String cycleId;
  final DateTime periodStart;
  final DateTime scheduledAt;
  final int eligibleCount;
  final double potAmount;

  /// Toutes les conditions du tirage sont remplies.
  final bool isUnlocked;
}

/// Bénéficiaire courant mis en avant sur le dashboard.
class CurrentBeneficiaryView {
  const CurrentBeneficiaryView({
    required this.tontineId,
    required this.tontineName,
    required this.cycleId,
    required this.memberName,
    required this.amount,
    required this.periodStart,
    required this.isPaidOut,
    this.avatarUrl,
  });

  final String tontineId;
  final String tontineName;
  final String cycleId;
  final String memberName;
  final String? avatarUrl;
  final double amount;
  final DateTime periodStart;
  final bool isPaidOut;
}

/// Point du graphique d'évolution des cotisations.
class TrendPoint {
  const TrendPoint({
    required this.periodStart,
    required this.collected,
    required this.expected,
  });

  final DateTime periodStart;
  final double collected;
  final double expected;
}

/// Données agrégées de l'écran d'accueil.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.organization,
    required this.membersCount,
    required this.activeTontines,
    required this.expectedThisPeriod,
    required this.collectedThisPeriod,
    required this.lateContributions,
    required this.myContributionDue,
    required this.myContributionPaid,
    required this.deadlines,
    required this.recentActivity,
    required this.trend,
    this.nextDraw,
    this.currentBeneficiary,
  });

  final Organization organization;
  final int membersCount;
  final int activeTontines;
  final double expectedThisPeriod;
  final double collectedThisPeriod;
  final int lateContributions;

  /// Montant que l'utilisateur connecté doit sur la période.
  final double myContributionDue;
  final double myContributionPaid;
  final List<UpcomingDeadline> deadlines;
  final List<AuditLog> recentActivity;
  final List<TrendPoint> trend;
  final UpcomingDraw? nextDraw;
  final CurrentBeneficiaryView? currentBeneficiary;

  double get remainingThisPeriod =>
      (expectedThisPeriod - collectedThisPeriod).clamp(0, double.infinity);

  double get collectionProgress => expectedThisPeriod <= 0
      ? 0
      : (collectedThisPeriod / expectedThisPeriod).clamp(0, 1);
}

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> load({
    required String organizationId,
    required String memberId,
  });
}
