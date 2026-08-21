import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/data/mock/mock_seed.dart';
import 'package:kadjane/domain/entities/app_notification.dart';
import 'package:kadjane/domain/entities/attachment.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/cash_transaction.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/entities/user.dart';

/// Base de données en mémoire utilisée par les repositories mock.
///
/// Elle joue le rôle du backend tant que celui-ci n'existe pas : mêmes règles
/// de cloisonnement multi-organisation, mêmes contraintes métier, latence
/// réseau simulée. Les repositories REST viendront la remplacer sans toucher
/// aux écrans.
class MockDatabase {
  MockDatabase({bool seed = true}) {
    if (seed) {
      MockSeed.populate(this);
    }
  }

  final List<User> users = <User>[];
  final Map<String, String> passwords = <String, String>{};
  final List<Organization> organizations = <Organization>[];
  final List<OrganizationMember> members = <OrganizationMember>[];
  final List<Tontine> tontines = <Tontine>[];
  final List<TontineParticipant> participants = <TontineParticipant>[];
  final List<TontineCycle> cycles = <TontineCycle>[];
  final List<Contribution> contributions = <Contribution>[];
  final List<DrawSession> draws = <DrawSession>[];
  final List<Beneficiary> beneficiaries = <Beneficiary>[];
  final List<Payout> payouts = <Payout>[];
  final List<CashTransaction> transactions = <CashTransaction>[];
  final List<AppNotification> notifications = <AppNotification>[];
  final List<AuditLog> auditLogs = <AuditLog>[];
  final List<Attachment> attachments = <Attachment>[];
  final List<Reminder> reminders = <Reminder>[];
  final List<ReminderCampaign> campaigns = <ReminderCampaign>[];
  final List<RoleDefinition> roleDefinitions = <RoleDefinition>[];

  int _sequence = 0;

  /// Identifiants lisibles et stables pour le mode démo.
  String nextId(String prefix) {
    _sequence++;
    return '${prefix}_${_sequence.toString().padLeft(5, '0')}';
  }

  /// Simule la latence réseau configurée pour l'environnement courant.
  Future<T> withLatency<T>(T Function() action) async {
    final Duration latency = AppConfig.current.networkLatency;
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    return action();
  }

  // --- Lectures utilitaires -------------------------------------------------

  User userById(String id) => users.firstWhere(
    (User u) => u.id == id,
    orElse: () => throw NotFoundException('user:$id'),
  );

  User? userByIdentifier(String identifier) {
    final String needle = identifier.trim().toLowerCase();
    for (final User user in users) {
      final bool matchesPhone =
          _digits(user.phone) == _digits(needle) && needle.isNotEmpty;
      final bool matchesEmail = (user.email ?? '').toLowerCase() == needle;
      if (matchesPhone || matchesEmail) {
        return user;
      }
    }
    return null;
  }

  Organization organizationById(String id) => organizations.firstWhere(
    (Organization o) => o.id == id,
    orElse: () => throw NotFoundException('organization:$id'),
  );

  OrganizationMember memberById(String id) => members.firstWhere(
    (OrganizationMember m) => m.id == id,
    orElse: () => throw NotFoundException('member:$id'),
  );

  OrganizationMember? memberOf({
    required String organizationId,
    required String userId,
  }) {
    for (final OrganizationMember m in members) {
      if (m.organizationId == organizationId && m.userId == userId) {
        return m;
      }
    }
    return null;
  }

  List<OrganizationMember> membersOf(String organizationId) => members
      .where((OrganizationMember m) => m.organizationId == organizationId)
      .toList(growable: false);

  Tontine tontineById(String id) => tontines.firstWhere(
    (Tontine t) => t.id == id,
    orElse: () => throw NotFoundException('tontine:$id'),
  );

  List<Tontine> tontinesOf(String organizationId) => tontines
      .where((Tontine t) => t.organizationId == organizationId)
      .toList(growable: false);

  List<TontineParticipant> participantsOf(String tontineId) => participants
      .where((TontineParticipant p) => p.tontineId == tontineId)
      .toList(growable: false);

  TontineParticipant participantById(String id) => participants.firstWhere(
    (TontineParticipant p) => p.id == id,
    orElse: () => throw NotFoundException('participant:$id'),
  );

  List<TontineCycle> cyclesOf(String tontineId) {
    final List<TontineCycle> result = cycles
        .where((TontineCycle c) => c.tontineId == tontineId)
        .toList();
    result.sort((TontineCycle a, TontineCycle b) => a.index.compareTo(b.index));
    return result;
  }

  TontineCycle cycleById(String id) => cycles.firstWhere(
    (TontineCycle c) => c.id == id,
    orElse: () => throw NotFoundException('cycle:$id'),
  );

  List<Contribution> contributionsOfCycle(String cycleId) => contributions
      .where((Contribution c) => c.cycleId == cycleId)
      .toList(growable: false);

  List<Contribution> contributionsOfTontine(String tontineId) => contributions
      .where((Contribution c) => c.tontineId == tontineId)
      .toList(growable: false);

  Beneficiary? beneficiaryOfCycle(String cycleId) {
    for (final Beneficiary b in beneficiaries) {
      if (b.cycleId == cycleId) {
        return b;
      }
    }
    return null;
  }

  Payout? payoutOfCycle(String cycleId) {
    for (final Payout p in payouts) {
      if (p.cycleId == cycleId) {
        return p;
      }
    }
    return null;
  }

  DrawSession? drawOfCycle(String cycleId) {
    for (final DrawSession d in draws) {
      if (d.cycleId == cycleId && d.status.isBinding) {
        return d;
      }
    }
    return null;
  }

  // --- Écritures utilitaires ------------------------------------------------

  void replaceParticipant(TontineParticipant participant) {
    final int index = participants.indexWhere(
      (TontineParticipant p) => p.id == participant.id,
    );
    if (index == -1) {
      throw NotFoundException('participant:${participant.id}');
    }
    participants[index] = participant;
  }

  void replaceCycle(TontineCycle cycle) {
    final int index = cycles.indexWhere((TontineCycle c) => c.id == cycle.id);
    if (index == -1) {
      throw NotFoundException('cycle:${cycle.id}');
    }
    cycles[index] = cycle;
  }

  void replaceContribution(Contribution contribution) {
    final int index = contributions.indexWhere(
      (Contribution c) => c.id == contribution.id,
    );
    if (index == -1) {
      throw NotFoundException('contribution:${contribution.id}');
    }
    contributions[index] = contribution;
  }

  void replaceDraw(DrawSession draw) {
    final int index = draws.indexWhere((DrawSession d) => d.id == draw.id);
    if (index == -1) {
      throw NotFoundException('draw:${draw.id}');
    }
    draws[index] = draw;
  }

  void replaceTontine(Tontine tontine) {
    final int index = tontines.indexWhere((Tontine t) => t.id == tontine.id);
    if (index == -1) {
      throw NotFoundException('tontine:${tontine.id}');
    }
    tontines[index] = tontine;
  }

  void replaceMember(OrganizationMember member) {
    final int index = members.indexWhere(
      (OrganizationMember m) => m.id == member.id,
    );
    if (index == -1) {
      throw NotFoundException('member:${member.id}');
    }
    members[index] = member;
  }

  void replaceOrganization(Organization organization) {
    final int index = organizations.indexWhere(
      (Organization o) => o.id == organization.id,
    );
    if (index == -1) {
      throw NotFoundException('organization:${organization.id}');
    }
    organizations[index] = organization;
  }

  List<Reminder> remindersOfCycle(String cycleId) => reminders
      .where((Reminder r) => r.cycleId == cycleId)
      .toList(growable: false);

  void replaceReminder(Reminder reminder) {
    final int index = reminders.indexWhere((Reminder r) => r.id == reminder.id);
    if (index != -1) {
      reminders[index] = reminder;
    }
  }

  void replaceRoleDefinition(RoleDefinition definition) {
    final int index = roleDefinitions.indexWhere(
      (RoleDefinition d) => d.id == definition.id,
    );
    if (index == -1) {
      roleDefinitions.add(definition);
      return;
    }
    roleDefinitions[index] = definition;
  }

  void replaceBeneficiary(Beneficiary beneficiary) {
    final int index = beneficiaries.indexWhere(
      (Beneficiary b) => b.id == beneficiary.id,
    );
    if (index == -1) {
      throw NotFoundException('beneficiary:${beneficiary.id}');
    }
    beneficiaries[index] = beneficiary;
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
