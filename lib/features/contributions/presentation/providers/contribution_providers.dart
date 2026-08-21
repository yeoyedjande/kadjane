import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';

/// Cotisations du membre connecté dans l'organisation active.
final AutoDisposeFutureProvider<List<Contribution>> myContributionsProvider =
    FutureProvider.autoDispose<List<Contribution>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      final OrganizationMember? membership = await ref.watch(
        currentMembershipProvider.future,
      );
      if (organizationId == null || membership == null) {
        return const <Contribution>[];
      }
      return ref
          .watch(contributionRepositoryProvider)
          .forMember(organizationId: organizationId, memberId: membership.id);
    });

/// Lignes attendues (payées ou non) pour un cycle donné.
final AutoDisposeFutureProviderFamily<List<ContributionSlot>, String>
cycleSlotsProvider = FutureProvider.autoDispose
    .family<List<ContributionSlot>, String>(
      (Ref ref, String cycleId) =>
          ref.watch(contributionRepositoryProvider).slotsForCycle(cycleId),
    );

/// Cotisations enregistrées pour un cycle (historique complet).
final AutoDisposeFutureProviderFamily<List<Contribution>, String>
cycleContributionsProvider = FutureProvider.autoDispose
    .family<List<Contribution>, String>(
      (Ref ref, String cycleId) =>
          ref.watch(contributionRepositoryProvider).forCycle(cycleId),
    );
