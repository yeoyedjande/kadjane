import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';

/// Appartenance d'un utilisateur à une organisation, avec son rôle.
class OrganizationMember {
  const OrganizationMember({
    required this.id,
    required this.organizationId,
    required this.user,
    required this.role,
    required this.joinedAt,
    this.status = MemberStatus.active,
    this.memberNumber,
  });

  final String id;
  final String organizationId;
  final User user;
  final OrgRole role;
  final MemberStatus status;
  final DateTime joinedAt;

  /// Numéro d'adhérent affiché sur la fiche membre.
  final String? memberNumber;

  String get userId => user.id;

  String get fullName => user.fullName;

  bool get isActive => status == MemberStatus.active;

  OrganizationMember copyWith({
    User? user,
    OrgRole? role,
    MemberStatus? status,
    String? memberNumber,
  }) => OrganizationMember(
    id: id,
    organizationId: organizationId,
    user: user ?? this.user,
    role: role ?? this.role,
    joinedAt: joinedAt,
    status: status ?? this.status,
    memberNumber: memberNumber ?? this.memberNumber,
  );
}
