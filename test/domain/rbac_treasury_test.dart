import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/data/dto/treasury_dto.dart';
import 'package:kadjane/domain/entities/cashbox.dart';
import 'package:kadjane/domain/entities/contribution_campaign.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/services/permission_service.dart';

/// Ce que le mobile doit savoir des droits et des cotisations.
///
/// Les règles financières sont éprouvées côté backend ; ici on protège la
/// lecture : un code inconnu ne doit pas se transformer en droit, et un taux
/// absent ne doit pas devenir zéro.
void main() {
  group('matrice locale des droits', () {
    const PermissionService service = PermissionService();

    test('le trésorier peut tenir la caisse', () {
      final Set<Permission> treasurer = service.defaultPermissionsOf(
        OrgRole.treasurer,
      );

      expect(treasurer, contains(Permission.cashboxView));
      expect(treasurer, contains(Permission.cashboxCreate));
      expect(treasurer, contains(Permission.cashTransactionCreate));
      expect(treasurer, contains(Permission.contributionCreate));
      expect(treasurer, contains(Permission.paymentCreate));
      expect(treasurer, contains(Permission.paymentConfirm));
      expect(treasurer, contains(Permission.payoutConfirm));
    });

    test('le trésorier ne touche ni aux rôles ni aux permissions', () {
      final Set<Permission> treasurer = service.defaultPermissionsOf(
        OrgRole.treasurer,
      );

      expect(treasurer, isNot(contains(Permission.roleAssign)));
      expect(treasurer, isNot(contains(Permission.roleCreate)));
      expect(treasurer, isNot(contains(Permission.permissionAssign)));
      // Fermer une caisse reste un acte d'administration.
      expect(treasurer, isNot(contains(Permission.cashboxClose)));
    });

    test('le commissaire aux comptes lit sans jamais écrire', () {
      final Set<Permission> auditor = service.defaultPermissionsOf(
        OrgRole.auditor,
      );

      expect(auditor, contains(Permission.cashboxView));
      expect(auditor, contains(Permission.auditView));
      expect(auditor, isNot(contains(Permission.cashTransactionCreate)));
      expect(auditor, isNot(contains(Permission.paymentCreate)));
      expect(auditor, isNot(contains(Permission.cashboxCreate)));
    });

    test('le membre consulte, il n\'encaisse pas', () {
      final Set<Permission> member = service.defaultPermissionsOf(
        OrgRole.member,
      );

      expect(member, contains(Permission.contributionView));
      expect(member, contains(Permission.paymentView));
      expect(member, isNot(contains(Permission.cashboxCreate)));
      expect(member, isNot(contains(Permission.paymentConfirm)));
    });
  });

  group('lecture des permissions servies', () {
    test('un code inconnu du client est ignoré, pas rabattu', () {
      // Régression : `fromCode` repliait sur `organizationView`, si bien qu'un
      // code d'une version plus récente accordait un droit au hasard.
      expect(Permission.tryFromCode('cashbox.create'), Permission.cashboxCreate);
      expect(Permission.tryFromCode('quelque.chose.de.neuf'), isNull);
    });
  });

  group('lecture des montants', () {
    test('un taux de recouvrement absent reste nul, jamais zéro', () {
      // Une cotisation à montant libre n'a pas d'attendu : 0 % laisserait
      // croire que personne n'a payé.
      final CampaignSummary summary = CampaignSummaryDto.fromJson(
        <String, dynamic>{
          'membersCount': 3,
          'expected': 0,
          'collected': 7500,
          'remaining': 0,
          'recoveryRate': null,
          'paidCount': 1,
          'partialCount': 0,
          'pendingCount': 2,
          'lateCount': 0,
          'exemptedCount': 0,
        },
      );

      expect(summary.recoveryRate, isNull);
      expect(summary.collected, 7500);
    });

    test('le solde vient du serveur, il n\'est pas recomposé', () {
      final Cashbox cashbox = CashboxDto.fromJson(<String, dynamic>{
        'id': 'box-1',
        'organizationId': 'org-1',
        'name': 'Caisse sociale',
        'currency': 'XOF',
        'openingBalance': 1000,
        'currentBalance': 38000,
        'inflows': 50000,
        'outflows': 13000,
        'status': 'open',
        'isDefault': true,
        'createdAt': '2026-08-01T00:00:00.000Z',
      });

      expect(cashbox.currentBalance, 38000);
      expect(cashbox.isOpen, isTrue);
    });

    test('une caisse fermée n\'accepte plus de mouvement', () {
      expect(CashboxStatus.fromCode('closed').acceptsTransactions, isFalse);
      expect(CashboxStatus.fromCode('suspended').acceptsTransactions, isFalse);
      expect(CashboxStatus.fromCode('open').acceptsTransactions, isTrue);
    });
  });

  group('statuts de cotisation', () {
    test('une exemption sort de l\'attendu sans être un impayé', () {
      expect(CampaignEntryStatus.exempted.isOwed, isFalse);
      expect(CampaignEntryStatus.cancelled.isOwed, isFalse);
      expect(CampaignEntryStatus.late_.isOwed, isTrue);
      expect(CampaignEntryStatus.partial.isOwed, isTrue);
    });

    test('les fonds de tontine ne vont pas à la caisse', () {
      // §22 OCTIES : la cagnotte d'un cycle ne se mélange pas à la caisse
      // générale de l'association.
      expect(ContributionType.tontine.feedsCashbox, isFalse);
      expect(ContributionType.association.feedsCashbox, isTrue);
      expect(ContributionType.exceptional.feedsCashbox, isTrue);
      expect(ContributionType.voluntary.feedsCashbox, isTrue);
    });

    test('une cotisation close n\'accepte plus de règlement', () {
      expect(CampaignStatus.closed.acceptsPayments, isFalse);
      expect(CampaignStatus.active.acceptsPayments, isTrue);
    });
  });
}
