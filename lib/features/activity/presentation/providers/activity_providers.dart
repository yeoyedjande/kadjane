import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/audit_log.dart';

/// Journal d'activité de l'organisation active.
final AutoDisposeFutureProvider<List<AuditLog>> activityLogsProvider =
    FutureProvider.autoDispose<List<AuditLog>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <AuditLog>[];
      }
      return ref
          .watch(auditRepositoryProvider)
          .list(organizationId: organizationId);
    });

/// Journal filtré sur une tontine (onglet « Historique »).
final AutoDisposeFutureProviderFamily<List<AuditLog>, String>
tontineActivityProvider = FutureProvider.autoDispose
    .family<List<AuditLog>, String>((Ref ref, String tontineId) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <AuditLog>[];
      }
      return ref
          .watch(auditRepositoryProvider)
          .list(organizationId: organizationId, tontineId: tontineId);
    });
