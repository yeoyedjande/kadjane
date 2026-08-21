import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/services/permission_service.dart';

void main() {
  const PermissionService service = PermissionService();

  group('Matrice des permissions', () {
    test('le membre consulte mais n\'écrit pas', () {
      expect(service.can(OrgRole.member, Permission.tontineView), isTrue);
      expect(service.can(OrgRole.member, Permission.contributionView), isTrue);
      expect(
        service.can(OrgRole.member, Permission.contributionRecord),
        isFalse,
      );
      expect(service.can(OrgRole.member, Permission.drawRun), isFalse);
      expect(service.can(OrgRole.member, Permission.auditView), isFalse);
    });

    test('le commissaire aux comptes est en lecture seule', () {
      expect(service.can(OrgRole.auditor, Permission.auditView), isTrue);
      expect(service.can(OrgRole.auditor, Permission.reportView), isTrue);
      expect(service.can(OrgRole.auditor, Permission.treasuryView), isTrue);
      expect(
        service.can(OrgRole.auditor, Permission.contributionRecord),
        isFalse,
      );
      expect(service.can(OrgRole.auditor, Permission.treasuryManage), isFalse);
    });

    test('le trésorier encaisse et verse mais ne lance pas le tirage', () {
      expect(
        service.can(OrgRole.treasurer, Permission.contributionRecord),
        isTrue,
      );
      expect(service.can(OrgRole.treasurer, Permission.payoutRecord), isTrue);
      expect(service.can(OrgRole.treasurer, Permission.treasuryManage), isTrue);
      expect(service.can(OrgRole.treasurer, Permission.drawRun), isFalse);
      expect(
        service.can(OrgRole.treasurer, Permission.organizationEdit),
        isFalse,
      );
    });

    test('le président lance le tirage sans gérer la caisse', () {
      expect(service.can(OrgRole.president, Permission.drawRun), isTrue);
      expect(
        service.can(OrgRole.president, Permission.tontineValidate),
        isTrue,
      );
      expect(
        service.can(OrgRole.president, Permission.contributionRecord),
        isFalse,
      );
      expect(service.can(OrgRole.president, Permission.drawOverride), isFalse);
    });

    test('l\'administrateur cumule les droits et peut forcer un tirage', () {
      expect(service.can(OrgRole.admin, Permission.drawRun), isTrue);
      expect(service.can(OrgRole.admin, Permission.drawOverride), isTrue);
      expect(service.can(OrgRole.admin, Permission.drawInvalidate), isTrue);
      expect(service.can(OrgRole.admin, Permission.memberCreate), isTrue);
      expect(service.can(OrgRole.admin, Permission.treasuryManage), isTrue);
    });

    test('le super admin dispose de toutes les permissions', () {
      expect(
        service.permissionsOf(OrgRole.superAdmin).length,
        Permission.values.length,
      );
    });

    test('canAll et canAny combinent correctement les droits', () {
      expect(
        service.canAll(OrgRole.treasurer, <Permission>[
          Permission.contributionRecord,
          Permission.payoutRecord,
        ]),
        isTrue,
      );
      expect(
        service.canAll(OrgRole.treasurer, <Permission>[
          Permission.contributionRecord,
          Permission.drawRun,
        ]),
        isFalse,
      );
      expect(
        service.canAny(OrgRole.member, <Permission>[
          Permission.drawRun,
          Permission.tontineView,
        ]),
        isTrue,
      );
    });
  });
}
