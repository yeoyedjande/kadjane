import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/repositories/audit_repository.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';

/// TODO(api): remplacer par `RestMemberRepository`
/// (/organizations/{id}/members).
class MockMemberRepository implements MemberRepository {
  MockMemberRepository(this._db, this._audit);

  final MockDatabase _db;
  final AuditRepository _audit;

  @override
  Future<PagedResult<OrganizationMember>> list({
    required String organizationId,
    String query = '',
    OrgRole? role,
    MemberStatus? status,
    int page = 0,
    int pageSize = 20,
  }) => _db.withLatency(() {
    final String needle = query.trim().toLowerCase();
    final List<OrganizationMember> filtered =
        _db.membersOf(organizationId).where((OrganizationMember m) {
          final bool matchesQuery =
              needle.isEmpty ||
              m.fullName.toLowerCase().contains(needle) ||
              m.user.phone.toLowerCase().contains(needle) ||
              (m.memberNumber ?? '').toLowerCase().contains(needle);
          final bool matchesRole = role == null || m.role == role;
          final bool matchesStatus = status == null || m.status == status;
          return matchesQuery && matchesRole && matchesStatus;
        }).toList()..sort(
          (OrganizationMember a, OrganizationMember b) =>
              a.fullName.compareTo(b.fullName),
        );

    final int from = page * pageSize;
    if (from >= filtered.length) {
      return PagedResult<OrganizationMember>(
        items: const <OrganizationMember>[],
        page: page,
        hasMore: false,
        total: filtered.length,
      );
    }
    final int to = (from + pageSize).clamp(0, filtered.length);
    return PagedResult<OrganizationMember>(
      items: filtered.sublist(from, to),
      page: page,
      hasMore: to < filtered.length,
      total: filtered.length,
    );
  });

  @override
  Future<OrganizationMember> byId(String memberId) =>
      _db.withLatency(() => _db.memberById(memberId));

  @override
  Future<OrganizationMember> create({
    required String organizationId,
    required MemberDraft draft,
    required String actorMemberId,
  }) async {
    final OrganizationMember member = await _db.withLatency(() {
      final User user = User(
        id: _db.nextId('usr'),
        firstName: draft.firstName,
        lastName: draft.lastName,
        phone: draft.phone,
        email: draft.email,
        gender: draft.gender,
        birthDate: draft.birthDate,
        avatarUrl: draft.avatarUrl,
        createdAt: DateTime.now(),
      );
      _db.users.add(user);
      final OrganizationMember created = OrganizationMember(
        id: _db.nextId('mbr'),
        organizationId: organizationId,
        user: user,
        role: draft.role,
        status: draft.status,
        joinedAt: DateTime.now(),
        memberNumber:
            'M-${(_db.membersOf(organizationId).length + 1).toString().padLeft(3, '0')}',
      );
      _db.members.add(created);
      return created;
    });

    await _audit.record(
      organizationId: organizationId,
      action: AuditAction.memberCreated,
      description: '${member.fullName} a rejoint l\'organisation.',
      actorMemberId: actorMemberId,
      targetType: 'member',
      targetId: member.id,
    );
    return member;
  }

  @override
  Future<OrganizationMember> update({
    required OrganizationMember member,
    required String actorMemberId,
  }) async {
    final OrganizationMember previous = _db.memberById(member.id);
    final OrganizationMember updated = await _db.withLatency(() {
      _db.replaceMember(member);
      final int userIndex = _db.users.indexWhere(
        (User u) => u.id == member.userId,
      );
      if (userIndex != -1) {
        _db.users[userIndex] = member.user;
      }
      return member;
    });

    await _audit.record(
      organizationId: member.organizationId,
      action: previous.role == member.role
          ? AuditAction.memberUpdated
          : AuditAction.memberRoleChanged,
      description: previous.role == member.role
          ? 'La fiche de ${member.fullName} a été mise à jour.'
          : 'Le rôle de ${member.fullName} a changé.',
      actorMemberId: actorMemberId,
      targetType: 'member',
      targetId: member.id,
    );
    return updated;
  }

  @override
  Future<MemberStats> statsOf(String memberId) => _db.withLatency(() {
    final double totalPaid = _db.contributions
        .where(
          (Contribution c) => c.memberId == memberId && c.countsAsCollected,
        )
        .fold<double>(0, (double sum, Contribution c) => sum + c.amount);

    final double totalReceived = _db.payouts
        .where((Payout p) => p.memberId == memberId && p.isPaid)
        .fold<double>(0, (double sum, Payout p) => sum + p.amount);

    final int tontines = _db.participants
        .where((TontineParticipant p) => p.memberId == memberId)
        .length;

    final int pending = _db.contributions
        .where(
          (Contribution c) =>
              c.memberId == memberId && c.status == ContributionStatus.pending,
        )
        .length;

    return MemberStats(
      totalPaid: totalPaid,
      totalReceived: totalReceived,
      tontinesCount: tontines,
      pendingContributions: pending,
      lateContributions: _lateCountOf(memberId),
    );
  });

  int _lateCountOf(String memberId) {
    final DateTime now = DateTime.now();
    int late = 0;
    for (final TontineParticipant participant in _db.participants.where(
      (TontineParticipant p) => p.memberId == memberId,
    )) {
      for (final cycle in _db.cyclesOf(participant.tontineId)) {
        if (now.isBefore(cycle.dueDate)) {
          continue;
        }
        final bool paid = _db
            .contributionsOfCycle(cycle.id)
            .any(
              (Contribution c) => c.memberId == memberId && c.countsAsCollected,
            );
        if (!paid) {
          late++;
        }
      }
    }
    return late;
  }
}
