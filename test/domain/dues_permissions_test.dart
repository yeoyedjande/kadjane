import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/services/permission_service.dart';

/// Qui fait quoi sur la caisse de l'association.
///
/// Le trésorier tient la caisse : il définit les cotisations **et** les
/// encaisse. Le simple membre, lui, ne fait que consulter ce qu'il doit.
void main() {
  group('droits sur la caisse', () {
    test('tout membre consulte ce qu\'il doit', () {
      for (final OrgRole role in OrgRole.values) {
        expect(
          const PermissionService().defaultPermissionsOf(role).contains(Permission.duesView),
          isTrue,
          reason: '$role doit voir ses cotisations',
        );
      }
    });

    test('le trésorier encaisse, pas le simple membre', () {
      expect(
        const PermissionService().defaultPermissionsOf(
          OrgRole.treasurer,
        ).contains(Permission.duesRecord),
        isTrue,
      );
      expect(
        const PermissionService().defaultPermissionsOf(
          OrgRole.member,
        ).contains(Permission.duesRecord),
        isFalse,
      );
    });

    test('le trésorier définit les cotisations, l\'administrateur aussi', () {
      for (final OrgRole role in <OrgRole>[OrgRole.treasurer, OrgRole.admin]) {
        expect(
          const PermissionService().defaultPermissionsOf(role).contains(Permission.duesManage),
          isTrue,
          reason: '$role doit pouvoir ouvrir une cotisation',
        );
      }
      // Ni le membre, ni le contrôleur, ni le président ne touchent aux plans :
      // c'est un geste de trésorerie, pas de gouvernance ni de consultation.
      for (final OrgRole role in <OrgRole>[
        OrgRole.member,
        OrgRole.auditor,
        OrgRole.president,
      ]) {
        expect(
          const PermissionService().defaultPermissionsOf(role).contains(Permission.duesManage),
          isFalse,
          reason: '$role ne définit pas les cotisations',
        );
      }
    });
  });

  group('échéance de caisse', () {
    DuesEntry entry({
      double expected = 5000,
      double paid = 0,
      DuesStatus status = DuesStatus.pending,
    }) => DuesEntry(
      id: 'e1',
      planId: 'p1',
      memberId: 'm1',
      periodLabel: 'Août 2026',
      dueDate: DateTime(2026, 8, 5),
      expectedAmount: expected,
      paidAmount: paid,
      status: status,
    );

    test('le reste dû ne descend jamais sous zéro', () {
      // Un trop-perçu ne doit pas produire un reste négatif à l'écran.
      expect(entry(paid: 6000).remainingAmount, 0);
      expect(entry(paid: 2000).remainingAmount, 3000);
    });

    test('une échéance annulée compte comme soldée', () {
      expect(entry(status: DuesStatus.cancelled).isSettled, isTrue);
      expect(entry(status: DuesStatus.paid).isSettled, isTrue);
      expect(entry(status: DuesStatus.late_).isSettled, isFalse);
    });

    test('un code inconnu retombe sur « en attente »', () {
      expect(DuesStatus.fromCode('inconnu'), DuesStatus.pending);
      expect(DuesStatus.fromCode('late'), DuesStatus.late_);
    });
  });
}
