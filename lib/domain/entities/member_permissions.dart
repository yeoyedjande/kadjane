import 'package:kadjane/domain/enums/permission.dart';

/// Droits d'un membre dans **une** organisation, tels que le serveur les voit.
///
/// Lus par membre et non par rôle : un rôle sur mesure — « Responsable
/// Cotisations » — n'a aucune entrée dans une matrice indexée par nom de rôle,
/// et l'application ne saurait pas quoi afficher.
///
/// Le même utilisateur peut être trésorier ici et simple membre ailleurs : il
/// y a donc une instance par appartenance, pas une par compte.
class MemberPermissions {
  const MemberPermissions({
    required this.organizationId,
    required this.memberId,
    required this.roleCode,
    required this.roleName,
    required this.permissions,
    this.roleId,
  });

  final String organizationId;
  final String memberId;

  /// Étiquette du membre (`treasurer`, `admin`…), ou le code d'un rôle sur
  /// mesure. Sert à l'affichage, jamais au contrôle d'accès.
  final String roleCode;

  /// Nom lisible du rôle, y compris pour un rôle sur mesure.
  final String roleName;

  final String? roleId;
  final Set<Permission> permissions;

  bool has(Permission permission) => permissions.contains(permission);

  bool hasAny(Iterable<Permission> candidates) =>
      candidates.any(permissions.contains);
}
