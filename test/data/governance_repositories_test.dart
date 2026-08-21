import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/data/repositories/mock_reminder_repository.dart';
import 'package:kadjane/data/repositories/mock_role_repository.dart';
import 'package:kadjane/domain/entities/audit_log.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/reminder.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/audit_action.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/enums/reminder_enums.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';
import 'package:kadjane/domain/repositories/reminder_repository.dart';
import 'package:kadjane/domain/services/dunning_service.dart';
import 'package:kadjane/domain/services/permission_service.dart';

import '../helpers/test_context.dart';

void main() {
  late TestContext ctx;
  late MockRoleRepository roles;
  late MockReminderRepository reminders;
  late String organizationId;

  setUp(() {
    ctx = TestContext();
    roles = MockRoleRepository(ctx.db, ctx.audit);
    reminders = MockReminderRepository(ctx.db, ctx.audit);
    organizationId = ctx.monthlyDrawTontine.organizationId;
  });

  group('Matrice des rôles', () {
    test('part des droits par défaut de Kadjane', () async {
      final List<RoleDefinition> definitions = await roles.definitions(
        organizationId,
      );

      expect(
        definitions.map((RoleDefinition d) => d.role),
        isNot(contains(OrgRole.superAdmin)),
      );
      final RoleDefinition treasurer = definitions.firstWhere(
        (RoleDefinition d) => d.role == OrgRole.treasurer,
      );
      expect(treasurer.isCustomized, isFalse);
      expect(treasurer.has(Permission.contributionRecord), isTrue);
      expect(treasurer.has(Permission.drawRun), isFalse);
    });

    test(
      'accorder un droit personnalise le rôle et laisse une trace',
      () async {
        final List<RoleDefinition> before = await roles.definitions(
          organizationId,
        );
        final RoleDefinition treasurer = before.firstWhere(
          (RoleDefinition d) => d.role == OrgRole.treasurer,
        );

        final RoleDefinition updated = await roles.update(
          definition: treasurer.toggle(Permission.drawRun, granted: true),
          actorMemberId: ctx.admin.id,
        );

        expect(updated.has(Permission.drawRun), isTrue);
        expect(updated.isCustomized, isTrue);

        // La définition est bien persistée pour la prochaine lecture.
        final List<RoleDefinition> after = await roles.definitions(
          organizationId,
        );
        expect(
          after
              .firstWhere((RoleDefinition d) => d.role == OrgRole.treasurer)
              .has(Permission.drawRun),
          isTrue,
        );

        final List<AuditLog> logs = await ctx.audit.list(
          organizationId: organizationId,
        );
        expect(
          logs.where((AuditLog log) => log.action == AuditAction.roleUpdated),
          isNotEmpty,
        );
      },
    );

    test('la surcharge s\'applique au service de permissions', () async {
      const PermissionService service = PermissionService();
      final List<RoleDefinition> definitions = await roles.definitions(
        organizationId,
      );
      final RoleDefinition treasurer = definitions.firstWhere(
        (RoleDefinition d) => d.role == OrgRole.treasurer,
      );
      await roles.update(
        definition: treasurer.toggle(Permission.drawRun, granted: true),
        actorMemberId: ctx.admin.id,
      );

      final Map<OrgRole, Set<Permission>> overrides =
          <OrgRole, Set<Permission>>{
            for (final RoleDefinition d in await roles.definitions(
              organizationId,
            ))
              d.role: d.permissions,
          };

      expect(service.can(OrgRole.treasurer, Permission.drawRun), isFalse);
      expect(
        service.can(
          OrgRole.treasurer,
          Permission.drawRun,
          overrides: overrides,
        ),
        isTrue,
      );
      // Le super administrateur garde tous ses droits quoi qu'il arrive.
      expect(
        service.can(
          OrgRole.superAdmin,
          Permission.drawOverride,
          overrides: <OrgRole, Set<Permission>>{
            OrgRole.superAdmin: <Permission>{},
          },
        ),
        isTrue,
      );
    });

    test('la réinitialisation restaure les droits par défaut', () async {
      final List<RoleDefinition> definitions = await roles.definitions(
        organizationId,
      );
      final RoleDefinition member = definitions.firstWhere(
        (RoleDefinition d) => d.role == OrgRole.member,
      );
      await roles.update(
        definition: member.toggle(Permission.treasuryManage, granted: true),
        actorMemberId: ctx.admin.id,
      );

      final RoleDefinition reset = await roles.resetToDefault(
        organizationId: organizationId,
        role: OrgRole.member,
        actorMemberId: ctx.admin.id,
      );

      expect(reset.has(Permission.treasuryManage), isFalse);
      expect(reset.isCustomized, isFalse);
    });
  });

  group('Relances', () {
    test('cible le membre qui n\'a pas payé la période en cours', () async {
      final List<DunningTarget> targets = await reminders.targetsForCycle(
        tontineId: ctx.monthlyDrawTontine.id,
        cycleId: ctx.currentCycle.id,
      );

      expect(targets.length, 1);
      expect(targets.single.memberName, contains('OUATTARA'));
      expect(targets.single.amountDue, 50000);
      // Une relance a déjà été envoyée dans le jeu de démonstration.
      expect(targets.single.reminderCount, greaterThanOrEqualTo(1));
    });

    test('remonte les impayés de toute l\'organisation', () async {
      final List<DunningTarget> targets = await reminders
          .targetsForOrganization(organizationId);

      expect(targets, isNotEmpty);
      expect(
        targets.map((DunningTarget t) => t.tontineId).toSet().length,
        greaterThanOrEqualTo(1),
      );
    });

    test('une campagne notifie le membre et alimente l\'audit', () async {
      final List<DunningTarget> targets = await reminders.targetsForCycle(
        tontineId: ctx.monthlyDrawTontine.id,
        cycleId: ctx.currentCycle.id,
      );
      final DunningTarget target = targets.single;
      final int notificationsBefore = ctx.db.notifications.length;

      final ReminderCampaignResult result = await reminders.sendCampaign(
        actorMemberId: ctx.treasurer.id,
        draft: ReminderCampaignDraft(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
          channels: const <ReminderChannel>[
            ReminderChannel.inApp,
            ReminderChannel.sms,
          ],
          messages: <String, String>{
            target.memberId: 'Merci de régulariser votre cotisation.',
          },
        ),
      );

      expect(result.campaign.targetCount, 1);
      expect(result.reminders.length, 2);
      // Le canal interne est délivré, le SMS attend la passerelle.
      expect(
        result.reminders
            .firstWhere((Reminder r) => r.channel == ReminderChannel.inApp)
            .status,
        ReminderStatus.sent,
      );
      expect(
        result.reminders
            .firstWhere((Reminder r) => r.channel == ReminderChannel.sms)
            .status,
        ReminderStatus.queued,
      );
      expect(ctx.db.notifications.length, notificationsBefore + 1);

      final List<AuditLog> logs = await ctx.audit.list(
        organizationId: organizationId,
      );
      expect(
        logs.where((AuditLog log) => log.action == AuditAction.reminderSent),
        isNotEmpty,
      );
    });

    test(
      'le membre retrouve ses relances et peut les marquer comme lues',
      () async {
        final OrganizationMember salif = ctx.db
            .membersOf(organizationId)
            .firstWhere(
              (OrganizationMember m) => m.fullName.contains('OUATTARA'),
            );

        final List<Reminder> mine = await reminders.forMember(
          organizationId: organizationId,
          memberId: salif.id,
        );
        expect(mine, isNotEmpty);
        expect(mine.first.isRead, isFalse);

        await reminders.markAsRead(mine.first.id);

        final List<Reminder> after = await reminders.forMember(
          organizationId: organizationId,
          memberId: salif.id,
        );
        expect(after.first.isRead, isTrue);
        expect(after.first.status, ReminderStatus.read);
      },
    );

    test(
      'plus personne à relancer une fois la cotisation enregistrée',
      () async {
        final List<DunningTarget> before = await reminders.targetsForCycle(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
        );
        expect(before, isNotEmpty);

        await ctx.contributions.record(
          actorMemberId: ctx.treasurer.id,
          draft: ContributionDraft(
            tontineId: before.single.tontineId,
            cycleId: before.single.cycleId,
            memberId: before.single.memberId,
            amount: before.single.amountDue,
            method: PaymentMethod.cash,
          ),
        );

        final List<DunningTarget> after = await reminders.targetsForCycle(
          tontineId: ctx.monthlyDrawTontine.id,
          cycleId: ctx.currentCycle.id,
        );
        expect(after, isEmpty);
      },
    );
  });
}
