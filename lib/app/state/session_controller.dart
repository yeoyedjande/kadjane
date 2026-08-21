import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Organisations auxquelles appartient l'utilisateur connecté.
final FutureProvider<List<Organization>> userOrganizationsProvider =
    FutureProvider<List<Organization>>((Ref ref) async {
      final User? user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <Organization>[];
      }
      return ref.watch(organizationRepositoryProvider).organizationsOf(user.id);
    });

/// Organisation active : cloisonne toutes les données affichées.
class ActiveOrganizationController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final List<Organization> organizations = await ref.watch(
      userOrganizationsProvider.future,
    );
    if (organizations.isEmpty) {
      return null;
    }
    final String? stored = await ref
        .read(keyValueStoreProvider)
        .getString(StorageKeys.activeOrganization);
    final bool storedIsValid =
        stored != null && organizations.any((Organization o) => o.id == stored);
    return storedIsValid ? stored : organizations.first.id;
  }

  Future<void> select(String organizationId) async {
    await ref
        .read(keyValueStoreProvider)
        .setString(StorageKeys.activeOrganization, organizationId);
    state = AsyncValue<String?>.data(organizationId);
  }
}

final AsyncNotifierProvider<ActiveOrganizationController, String?>
activeOrganizationIdProvider =
    AsyncNotifierProvider<ActiveOrganizationController, String?>(
      ActiveOrganizationController.new,
    );

/// Organisation active complète.
final FutureProvider<Organization?> activeOrganizationProvider =
    FutureProvider<Organization?>((Ref ref) async {
      final String? id = await ref.watch(activeOrganizationIdProvider.future);
      if (id == null) {
        return null;
      }
      return ref.watch(organizationRepositoryProvider).byId(id);
    });

/// Appartenance (donc rôle) de l'utilisateur dans l'organisation active.
final FutureProvider<OrganizationMember?> currentMembershipProvider =
    FutureProvider<OrganizationMember?>((Ref ref) async {
      final User? user = ref.watch(currentUserProvider);
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (user == null || organizationId == null) {
        return null;
      }
      return ref
          .watch(organizationRepositoryProvider)
          .membershipOf(organizationId: organizationId, userId: user.id);
    });

/// Matrice des droits de l'organisation active, personnalisations comprises.
///
/// Elle est définie depuis la console d'administration et s'applique
/// immédiatement à l'application mobile.
final FutureProvider<Map<OrgRole, Set<Permission>>>
organizationRoleMatrixProvider = FutureProvider<Map<OrgRole, Set<Permission>>>((
  Ref ref,
) async {
  final String? organizationId = await ref.watch(
    activeOrganizationIdProvider.future,
  );
  if (organizationId == null) {
    return const <OrgRole, Set<Permission>>{};
  }
  final List<RoleDefinition> definitions = await ref
      .watch(roleRepositoryProvider)
      .definitions(organizationId);
  return <OrgRole, Set<Permission>>{
    for (final RoleDefinition definition in definitions)
      definition.role: definition.permissions,
  };
});

/// Permissions effectives de l'utilisateur dans l'organisation active.
final Provider<Set<Permission>> currentPermissionsProvider =
    Provider<Set<Permission>>((Ref ref) {
      final OrganizationMember? membership = ref
          .watch(currentMembershipProvider)
          .valueOrNull;
      if (membership == null) {
        return const <Permission>{};
      }
      final Map<OrgRole, Set<Permission>>? overrides = ref
          .watch(organizationRoleMatrixProvider)
          .valueOrNull;
      return ref
          .watch(permissionServiceProvider)
          .permissionsOf(membership.role, overrides: overrides);
    });

/// Helper : `ref.watch(canProvider(Permission.drawRun))`.
final ProviderFamily<bool, Permission> canProvider =
    Provider.family<bool, Permission>(
      (Ref ref, Permission permission) =>
          ref.watch(currentPermissionsProvider).contains(permission),
    );
