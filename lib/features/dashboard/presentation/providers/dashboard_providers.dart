import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/repositories/dashboard_repository.dart';

/// Données agrégées de l'écran d'accueil pour l'organisation active.
final AutoDisposeFutureProvider<DashboardSnapshot?> dashboardProvider =
    FutureProvider.autoDispose<DashboardSnapshot?>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      final OrganizationMember? membership = await ref.watch(
        currentMembershipProvider.future,
      );
      if (organizationId == null || membership == null) {
        return null;
      }
      return ref
          .watch(dashboardRepositoryProvider)
          .load(organizationId: organizationId, memberId: membership.id);
    });
