import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Droits accordés à un rôle **dans une organisation donnée**.
///
/// Chaque organisation part de la matrice par défaut de Kadjane et peut
/// l'ajuster depuis la console d'administration : un trésorier peut, par
/// exemple, se voir accorder le droit de lancer les tirages. Les définitions
/// sont ensuite appliquées partout, y compris dans l'application mobile.
class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.organizationId,
    required this.role,
    required this.permissions,
    required this.updatedAt,
    this.isCustomized = false,
    this.updatedByMemberId,
  });

  final String id;
  final String organizationId;
  final OrgRole role;
  final Set<Permission> permissions;

  /// Vrai si l'organisation s'écarte de la matrice par défaut.
  final bool isCustomized;
  final DateTime updatedAt;
  final String? updatedByMemberId;

  bool has(Permission permission) => permissions.contains(permission);

  RoleDefinition copyWith({
    Set<Permission>? permissions,
    bool? isCustomized,
    DateTime? updatedAt,
    String? updatedByMemberId,
  }) => RoleDefinition(
    id: id,
    organizationId: organizationId,
    role: role,
    permissions: permissions ?? this.permissions,
    updatedAt: updatedAt ?? this.updatedAt,
    isCustomized: isCustomized ?? this.isCustomized,
    updatedByMemberId: updatedByMemberId ?? this.updatedByMemberId,
  );

  /// Ajoute ou retire un droit et marque la définition comme personnalisée.
  RoleDefinition toggle(Permission permission, {required bool granted}) {
    final Set<Permission> next = <Permission>{...permissions};
    if (granted) {
      next.add(permission);
    } else {
      next.remove(permission);
    }
    return copyWith(
      permissions: next,
      isCustomized: true,
      updatedAt: DateTime.now(),
    );
  }
}
