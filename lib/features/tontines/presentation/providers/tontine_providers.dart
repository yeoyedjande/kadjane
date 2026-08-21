import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Toutes les données nécessaires à la page détail d'une tontine.
class TontineDetailData {
  const TontineDetailData({
    required this.summary,
    required this.participants,
    required this.cycles,
    required this.beneficiaries,
    required this.draws,
    required this.payouts,
    this.currentCycle,
    this.eligibility,
  });

  final TontineSummary summary;
  final List<TontineParticipant> participants;
  final List<TontineCycle> cycles;
  final List<Beneficiary> beneficiaries;
  final List<DrawSession> draws;
  final List<Payout> payouts;
  final TontineCycle? currentCycle;
  final DrawEligibility? eligibility;

  Tontine get tontine => summary.tontine;

  Beneficiary? beneficiaryOf(String cycleId) {
    for (final Beneficiary b in beneficiaries) {
      if (b.cycleId == cycleId) {
        return b;
      }
    }
    return null;
  }

  Payout? payoutOf(String cycleId) {
    for (final Payout p in payouts) {
      if (p.cycleId == cycleId) {
        return p;
      }
    }
    return null;
  }
}

/// Tontines de l'organisation active.
final AutoDisposeFutureProvider<List<TontineSummary>> tontineSummariesProvider =
    FutureProvider.autoDispose<List<TontineSummary>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <TontineSummary>[];
      }
      return ref
          .watch(tontineRepositoryProvider)
          .list(organizationId: organizationId);
    });

/// Détail complet d'une tontine.
final AutoDisposeFutureProviderFamily<TontineDetailData, String>
tontineDetailProvider = FutureProvider.autoDispose
    .family<TontineDetailData, String>((Ref ref, String tontineId) async {
      final TontineRepository repository = ref.watch(tontineRepositoryProvider);
      final TontineSummary summary = await repository.summaryOf(tontineId);
      final List<TontineParticipant> participants = await repository
          .participants(tontineId);
      final List<TontineCycle> cycles = await repository.cycles(tontineId);
      final TontineCycle? currentCycle = await repository.currentCycle(
        tontineId,
      );
      final List<Beneficiary> beneficiaries = await ref
          .watch(payoutRepositoryProvider)
          .beneficiariesOf(tontineId);
      final List<Payout> payouts = await ref
          .watch(payoutRepositoryProvider)
          .payoutsOf(tontineId);
      final List<DrawSession> draws = await ref
          .watch(drawRepositoryProvider)
          .historyOf(tontineId);

      DrawEligibility? eligibility;
      if (currentCycle != null) {
        eligibility = await ref
            .watch(drawRepositoryProvider)
            .eligibility(tontineId: tontineId, cycleId: currentCycle.id);
      }

      return TontineDetailData(
        summary: summary,
        participants: participants,
        cycles: cycles,
        beneficiaries: beneficiaries,
        draws: draws,
        payouts: payouts,
        currentCycle: currentCycle,
        eligibility: eligibility,
      );
    });

/// Membres sélectionnables lors de la création d'une tontine.
final AutoDisposeFutureProvider<List<TontineSummary>> myTontinesProvider =
    FutureProvider.autoDispose<List<TontineSummary>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      final membership = await ref.watch(currentMembershipProvider.future);
      if (organizationId == null || membership == null) {
        return const <TontineSummary>[];
      }
      return ref
          .watch(tontineRepositoryProvider)
          .list(organizationId: organizationId, memberId: membership.id);
    });
