import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';

class MemberDraft {
  const MemberDraft({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    this.email,
    this.gender = Gender.unspecified,
    this.birthDate,
    this.avatarUrl,
    this.status = MemberStatus.active,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final OrgRole role;
  final String? email;
  final Gender gender;
  final DateTime? birthDate;
  final String? avatarUrl;
  final MemberStatus status;
}

/// Statistiques agrégées affichées sur la fiche d'un membre.
class MemberStats {
  const MemberStats({
    required this.totalPaid,
    required this.totalReceived,
    required this.tontinesCount,
    required this.pendingContributions,
    required this.lateContributions,
  });

  final double totalPaid;
  final double totalReceived;
  final int tontinesCount;
  final int pendingContributions;
  final int lateContributions;
}

/// Page de résultats (pagination / lazy loading).
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
  });

  final List<T> items;
  final int page;
  final bool hasMore;
  final int total;
}

abstract interface class MemberRepository {
  Future<PagedResult<OrganizationMember>> list({
    required String organizationId,
    String query = '',
    OrgRole? role,
    MemberStatus? status,
    int page = 0,
    int pageSize = 20,
  });

  Future<OrganizationMember> byId(String memberId);

  Future<OrganizationMember> create({
    required String organizationId,
    required MemberDraft draft,
    required String actorMemberId,
  });

  Future<OrganizationMember> update({
    required OrganizationMember member,
    required String actorMemberId,
  });

  Future<MemberStats> statsOf(String memberId);

  // TODO(api): invitation par lien / code (POST /organizations/{id}/invitations).
}
