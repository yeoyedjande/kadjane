import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/storage/key_value_store.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

import '../helpers/test_context.dart';

/// Gestion de la caisse par le trésorier : ouvrir une cotisation, l'ajuster,
/// la suspendre, encaisser.
void main() {
  late TestContext ctx;
  late String organizationId;

  setUp(() {
    ctx = TestContext();
    organizationId = ctx.monthlyDrawTontine.organizationId;
  });

  Future<DuesPlan> planNamed(String name) async {
    final List<DuesPlan> plans = await ctx.dues.plans(organizationId);
    return plans.firstWhere((DuesPlan p) => p.name == name);
  }

  group('cotisations de caisse', () {
    test('créer une cotisation engendre une échéance par membre actif', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          startDate: DateTime.now(),
        ),
      );

      final List<DuesEntry> entries = await ctx.dues.entries(
        organizationId,
        plan.id,
      );
      final int activeMembers = ctx.db
          .membersOf(organizationId)
          .where((OrganizationMember m) => m.isActive)
          .length;

      expect(plan.isActive, isTrue);
      expect(entries, hasLength(activeMembers));
      expect(
        entries.every((DuesEntry e) => e.expectedAmount == 3000),
        isTrue,
        reason: 'une caisse commune demande le même montant à chacun',
      );
    });

    test('deux cotisations ne peuvent pas porter le même nom', () async {
      await ctx.dues.createPlan(
        organizationId,
        const DuesPlanDraft(name: 'Caisse imprévus', amount: 3000),
      );

      expect(
        () => ctx.dues.createPlan(
          organizationId,
          const DuesPlanDraft(name: 'caisse imprévus', amount: 1000),
        ),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('un montant nul est refusé', () async {
      expect(
        () => ctx.dues.createPlan(
          organizationId,
          const DuesPlanDraft(name: 'Caisse vide', amount: 0),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('un nouveau montant ne réécrit pas les échéances déjà dues', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          startDate: DateTime.now(),
        ),
      );
      await ctx.dues.updatePlan(organizationId, plan.id, amount: 7000);

      final List<DuesEntry> entries = await ctx.dues.entries(
        organizationId,
        plan.id,
      );
      expect(entries.every((DuesEntry e) => e.expectedAmount == 3000), isTrue);
      expect((await planNamed('Caisse imprévus')).amount, 7000);
    });

    test('une cotisation suspendue n\'engendre plus d\'échéance', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          // Trois mois en arrière : la reprise devrait sinon combler le retard.
          startDate: DateTime(
            DateTime.now().year,
            DateTime.now().month - 3,
          ),
        ),
      );
      final int before = (await ctx.dues.entries(
        organizationId,
        plan.id,
      )).length;

      await ctx.dues.updatePlan(
        organizationId,
        plan.id,
        status: DuesPlanStatus.paused,
      );
      ctx.db.duesEntries.removeWhere((DuesEntry e) => e.planId == plan.id);
      final List<DuesEntry> after = await ctx.dues.entries(
        organizationId,
        plan.id,
      );

      expect(before, greaterThan(0));
      expect(after, isEmpty);
    });

    test('un identifiant d\'une autre organisation reste introuvable', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        const DuesPlanDraft(name: 'Caisse imprévus', amount: 3000),
      );
      final String otherOrganization = ctx.db.organizations
          .firstWhere((dynamic o) => o.id != organizationId)
          .id;

      expect(
        () => ctx.dues.entries(otherOrganization, plan.id),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('encaissement', () {
    test('un règlement partiel laisse l\'échéance ouverte', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          startDate: DateTime.now(),
        ),
      );
      final DuesEntry entry = (await ctx.dues.entries(
        organizationId,
        plan.id,
      )).first;

      await ctx.dues.recordPayment(
        entryId: entry.id,
        amount: 1000,
        method: PaymentMethod.cash,
      );

      final DuesEntry updated = (await ctx.dues.entries(
        organizationId,
        plan.id,
      )).firstWhere((DuesEntry e) => e.id == entry.id);
      expect(updated.status, DuesStatus.partial);
      expect(updated.remainingAmount, 2000);
      expect((await planNamed('Caisse imprévus')).collectedTotal, 1000);
    });

    test('le solde complet clôt l\'échéance', () async {
      final DuesPlan plan = await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          startDate: DateTime.now(),
        ),
      );
      final DuesEntry entry = (await ctx.dues.entries(
        organizationId,
        plan.id,
      )).first;

      await ctx.dues.recordPayment(
        entryId: entry.id,
        amount: 3000,
        method: PaymentMethod.wave,
      );

      final DuesEntry updated = (await ctx.dues.entries(
        organizationId,
        plan.id,
      )).firstWhere((DuesEntry e) => e.id == entry.id);
      expect(updated.isSettled, isTrue);
      expect(updated.remainingAmount, 0);
    });
  });

  group('vue du membre', () {
    test('chacun ne voit que ses propres échéances impayées', () async {
      final OrganizationMember member = ctx.db
          .membersOf(organizationId)
          .firstWhere((OrganizationMember m) => m.isActive);
      await ctx.store.setString(StorageKeys.currentUserId, member.userId);

      await ctx.dues.createPlan(
        organizationId,
        DuesPlanDraft(
          name: 'Caisse imprévus',
          amount: 3000,
          frequency: TontineFrequency.monthly,
          startDate: DateTime.now(),
        ),
      );

      final List<DuesEntry> mine = await ctx.dues.myOutstanding(
        organizationId,
      );
      expect(mine, isNotEmpty);
      expect(mine.every((DuesEntry e) => e.memberId == member.id), isTrue);
      expect(mine.every((DuesEntry e) => !e.isSettled), isTrue);
    });

    test('sans session ouverte, rien n\'est révélé', () async {
      await ctx.dues.createPlan(
        organizationId,
        const DuesPlanDraft(name: 'Caisse imprévus', amount: 3000),
      );

      expect(await ctx.dues.myOutstanding(organizationId), isEmpty);
    });
  });
}
