import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';

/// Sources de la trésorerie du trésorier.
///
/// Tous les montants viennent du serveur : aucun n'est recomposé ici. Un solde
/// calculé sur une page partielle serait faux — et d'autant plus dangereux
/// qu'il aurait l'air juste.

/// Attendu, encaissé, reste, retard, et les soldes de caisse.
final AutoDisposeFutureProvider<FinancialDashboard?> financialDashboardProvider =
    FutureProvider.autoDispose<FinancialDashboard?>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return null;
      }
      return ref
          .watch(cashboxRepositoryProvider)
          .financialDashboard(organizationId);
    });

final AutoDisposeFutureProvider<List<Cashbox>> cashboxesProvider =
    FutureProvider.autoDispose<List<Cashbox>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <Cashbox>[];
      }
      return ref.watch(cashboxRepositoryProvider).cashboxes(organizationId);
    });

/// Cotisations associatives, exceptionnelles et volontaires.
///
/// Les cotisations de tontine n'y figurent pas : elles alimentent la cagnotte
/// d'un cycle et se consultent depuis la tontine.
final AutoDisposeFutureProvider<List<ContributionCampaign>> campaignsProvider =
    FutureProvider.autoDispose<List<ContributionCampaign>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <ContributionCampaign>[];
      }
      return ref.watch(cashboxRepositoryProvider).campaigns(organizationId);
    });

/// Fiche d'une cotisation, suivi individuel compris.
final AutoDisposeFutureProviderFamily<ContributionCampaign, String>
campaignProvider =
    FutureProvider.autoDispose.family<ContributionCampaign, String>(
      (Ref ref, String campaignId) =>
          ref.watch(cashboxRepositoryProvider).campaign(campaignId),
    );

/// Ce qui reste dû. Les exemptions en sont exclues : elles ne sont plus
/// attendues, ce ne sont pas des impayés.
final AutoDisposeFutureProvider<List<CampaignEntry>> unpaidProvider =
    FutureProvider.autoDispose<List<CampaignEntry>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <CampaignEntry>[];
      }
      return ref.watch(cashboxRepositoryProvider).unpaid(organizationId);
    });
