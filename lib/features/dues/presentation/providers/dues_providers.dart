import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';

/// Cotisations de caisse de l'organisation active, synthèse comprise.
final AutoDisposeFutureProvider<List<DuesPlan>> duesPlansProvider =
    FutureProvider.autoDispose<List<DuesPlan>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <DuesPlan>[];
      }
      return ref.watch(duesRepositoryProvider).plans(organizationId);
    });

/// Clé de lecture des échéances : une cotisation, éventuellement une période.
class DuesEntriesQuery {
  const DuesEntriesQuery(this.planId, {this.period});

  final String planId;

  /// `null` pour toutes les périodes.
  final int? period;

  @override
  bool operator ==(Object other) =>
      other is DuesEntriesQuery &&
      other.planId == planId &&
      other.period == period;

  @override
  int get hashCode => Object.hash(planId, period);
}

/// Échéances d'une cotisation, tous membres confondus.
final AutoDisposeFutureProviderFamily<List<DuesEntry>, DuesEntriesQuery>
duesEntriesProvider = FutureProvider.autoDispose
    .family<List<DuesEntry>, DuesEntriesQuery>((
      Ref ref,
      DuesEntriesQuery query,
    ) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <DuesEntry>[];
      }
      return ref
          .watch(duesRepositoryProvider)
          .entries(organizationId, query.planId, period: query.period);
    });

/// Ce que le membre connecté doit encore à la caisse.
final AutoDisposeFutureProvider<List<DuesEntry>> myDuesProvider =
    FutureProvider.autoDispose<List<DuesEntry>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <DuesEntry>[];
      }
      return ref.watch(duesRepositoryProvider).myOutstanding(organizationId);
    });

/// Recharge tout ce qui dépend de la caisse après une écriture.
///
/// Un encaissement change à la fois la synthèse du plan, la liste des
/// échéances et la situation personnelle du membre : les invalider ensemble
/// évite d'afficher trois vérités différentes.
void refreshDues(WidgetRef ref) {
  ref
    ..invalidate(duesPlansProvider)
    ..invalidate(duesEntriesProvider)
    ..invalidate(myDuesProvider);
}
