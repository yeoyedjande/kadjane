import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Raison pour laquelle un tirage est bloqué.
enum DrawBlockReason {
  none,
  tontineNotActive,
  alreadyDrawn,
  missingContributions,
  noEligibleParticipant,
  orderAlreadyDefined,
}

/// Résultat de l'évaluation des conditions d'un tirage.
class DrawEligibility {
  const DrawEligibility({
    required this.allowed,
    required this.reason,
    required this.missingContributions,
    required this.canOverride,
  });

  const DrawEligibility.allowed()
    : allowed = true,
      reason = DrawBlockReason.none,
      missingContributions = 0,
      canOverride = false;

  final bool allowed;
  final DrawBlockReason reason;
  final int missingContributions;

  /// Vrai si un administrateur peut forcer le tirage (avec audit).
  final bool canOverride;
}

/// Situation financière d'un cycle.
class CycleFinancials {
  const CycleFinancials({
    required this.expected,
    required this.collected,
    required this.paidMembers,
    required this.totalMembers,
  });

  final double expected;
  final double collected;
  final int paidMembers;
  final int totalMembers;

  double get remaining => (expected - collected).clamp(0, double.infinity);

  int get unpaidMembers => (totalMembers - paidMembers).clamp(0, totalMembers);

  double get progress => expected <= 0 ? 0 : (collected / expected).clamp(0, 1);

  bool get isComplete => collected >= expected && expected > 0;
}

/// Règles métier de la tontine, indépendantes de toute source de données.
class TontineRulesService {
  const TontineRulesService();

  /// Participants pouvant encore être tirés au sort.
  ///
  /// Un ancien bénéficiaire reste participant actif mais n'est plus éligible.
  List<TontineParticipant> eligibleForDraw(
    List<TontineParticipant> participants,
  ) => participants
      .where(
        (TontineParticipant p) =>
            p.isActive && p.isEligibleForDraw && !p.hasReceivedPot,
      )
      .toList(growable: false);

  /// Participants devant cotiser sur la période (y compris les bénéficiaires).
  List<TontineParticipant> contributors(
    List<TontineParticipant> participants,
  ) => participants
      .where((TontineParticipant p) => p.mustKeepContributing)
      .toList(growable: false);

  /// Montant réellement collecté : seules les cotisations confirmées comptent.
  double collectedAmount(List<Contribution> contributions) => contributions
      .where((Contribution c) => c.countsAsCollected)
      .fold<double>(0, (double sum, Contribution c) => sum + c.amount);

  /// Membres ayant une cotisation confirmée sur le cycle.
  Set<String> paidMemberIds(List<Contribution> contributions) => contributions
      .where((Contribution c) => c.countsAsCollected)
      .map((Contribution c) => c.memberId)
      .toSet();

  CycleFinancials financialsFor({
    required Tontine tontine,
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
  }) {
    final List<TontineParticipant> due = contributors(participants);
    final Set<String> paid = paidMemberIds(contributions);
    return CycleFinancials(
      expected: tontine.contributionAmount * due.length,
      collected: collectedAmount(contributions),
      paidMembers: due
          .where((TontineParticipant p) => paid.contains(p.memberId))
          .length,
      totalMembers: due.length,
    );
  }

  /// Membres en retard : pas de cotisation confirmée après la date limite.
  List<TontineParticipant> lateParticipants({
    required TontineCycle cycle,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
    required OrganizationSettings settings,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime limit = cycle.dueDate.add(
      Duration(days: settings.latePaymentGraceDays),
    );
    if (reference.isBefore(limit)) {
      return const <TontineParticipant>[];
    }
    final Set<String> paid = paidMemberIds(contributions);
    return contributors(participants)
        .where((TontineParticipant p) => !paid.contains(p.memberId))
        .toList(growable: false);
  }

  /// Vérifie toutes les conditions d'un tirage périodique (mode A).
  DrawEligibility evaluateDraw({
    required Tontine tontine,
    required TontineCycle cycle,
    required OrganizationSettings settings,
    required List<TontineParticipant> participants,
    required List<Contribution> contributions,
  }) {
    if (tontine.status != TontineStatus.active) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.tontineNotActive,
        missingContributions: 0,
        canOverride: false,
      );
    }
    if (cycle.hasBeneficiary) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.alreadyDrawn,
        missingContributions: 0,
        canOverride: false,
      );
    }
    final List<TontineParticipant> eligible = eligibleForDraw(participants);
    if (eligible.isEmpty) {
      return const DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.noEligibleParticipant,
        missingContributions: 0,
        canOverride: false,
      );
    }
    final CycleFinancials financials = financialsFor(
      tontine: tontine,
      cycle: cycle,
      participants: participants,
      contributions: contributions,
    );
    if (settings.requireFullPaymentBeforeDraw && financials.unpaidMembers > 0) {
      return DrawEligibility(
        allowed: false,
        reason: DrawBlockReason.missingContributions,
        missingContributions: financials.unpaidMembers,
        canOverride: settings.allowDrawOverride,
      );
    }
    return const DrawEligibility.allowed();
  }

  /// Position d'un membre dans une tontine à ordre prédéfini (modes B et C).
  TontineParticipant? participantOf(
    List<TontineParticipant> participants,
    String memberId,
  ) {
    for (final TontineParticipant p in participants) {
      if (p.memberId == memberId) {
        return p;
      }
    }
    return null;
  }
}
