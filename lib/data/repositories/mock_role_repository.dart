import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/role_repository.dart';
import 'package:kadjane/domain/services/permission_service.dart';

/// Matrice des droits en mémoire.
///
/// Les définitions sont créées à la volée à partir de la matrice par défaut :
/// une organisation qui n'a jamais personnalisé ses rôles n'a rien à stocker.
///
/// TODO(api): remplacer par `RestRoleRepository` (/organizations/{id}/roles).
class MockRoleRepository implements RoleRepository {
  MockRoleRepository(
    this._db,
    this._audit, [
    this._permissions = const PermissionService(),
  ]);

  final MockDatabase _db;
  final AuditRepository _audit;
  final PermissionService _permissions;

  @override
  Future<List<RoleDefinition>> definitions(String organizationId) =>
      _db.withLatency(() {
        final List<RoleDefinition> result = <RoleDefinition>[];
        for (final OrgRole role in OrgRole.values) {
          if (role == OrgRole.superAdmin) {
            // Le super administrateur n'est pas éditable : il garde tout.
            continue;
          }
          result.add(_definitionFor(organizationId, role));
        }
        return List<RoleDefinition>.unmodifiable(result);
      });

  @override
  Future<RoleDefinition> update({
    required RoleDefinition definition,
    required String actorMemberId,
  }) async {
    final RoleDefinition saved = await _db.withLatency(() {
      final RoleDefinition next = definition.copyWith(
        updatedAt: DateTime.now(),
        updatedByMemberId: actorMemberId,
        isCustomized: !_matchesDefault(definition),
      );
      _db.replaceRoleDefinition(next);
      return next;
    });

    await _audit.record(
      organizationId: saved.organizationId,
      action: AuditAction.roleUpdated,
      description:
          'Les droits du rôle ${saved.role.code} ont été modifiés '
          '(${saved.permissions.length} permissions).',
      actorMemberId: actorMemberId,
      targetType: 'role',
      targetId: saved.role.code,
      metadata: <String, Object?>{
        'permissions': saved.permissions.map((Permission p) => p.code).toList(),
      },
    );
    return saved;
  }

  @override
  Future<RoleDefinition> resetToDefault({
    required String organizationId,
    required OrgRole role,
    required String actorMemberId,
  }) async {
    final RoleDefinition saved = await _db.withLatency(() {
      final RoleDefinition next = RoleDefinition(
        id: _idFor(organizationId, role),
        organizationId: organizationId,
        role: role,
        permissions: _permissions.defaultPermissionsOf(role),
        updatedAt: DateTime.now(),
        updatedByMemberId: actorMemberId,
      );
      _db.replaceRoleDefinition(next);
      return next;
    });

    await _audit.record(
      organizationId: organizationId,
      action: AuditAction.roleReset,
      description:
          'Les droits par défaut du rôle ${role.code} ont été rétablis.',
      actorMemberId: actorMemberId,
      targetType: 'role',
      targetId: role.code,
    );
    return saved;
  }

  // --- Interne -------------------------------------------------------------

  String _idFor(String organizationId, OrgRole role) =>
      'rol_${organizationId}_${role.code}';

  RoleDefinition _definitionFor(String organizationId, OrgRole role) {
    final String id = _idFor(organizationId, role);
    for (final RoleDefinition definition in _db.roleDefinitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return RoleDefinition(
      id: id,
      organizationId: organizationId,
      role: role,
      permissions: _permissions.defaultPermissionsOf(role),
      updatedAt: DateTime.now(),
    );
  }

  bool _matchesDefault(RoleDefinition definition) {
    final Set<Permission> defaults = _permissions.defaultPermissionsOf(
      definition.role,
    );
    return defaults.length == definition.permissions.length &&
        defaults.every(definition.permissions.contains);
  }
}
