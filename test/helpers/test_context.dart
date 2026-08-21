import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/utils/random_source.dart';
import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/data/repositories/mock_audit_repository.dart';
import 'package:kadjane/data/repositories/mock_contribution_repository.dart';
import 'package:kadjane/data/repositories/mock_draw_repository.dart';
import 'package:kadjane/data/repositories/mock_payout_repository.dart';
import 'package:kadjane/data/repositories/mock_tontine_repository.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Contexte de test : base mock ensemencée + repositories prêts à l'emploi.
class TestContext {
  TestContext({int seed = 42}) {
    // Latence désactivée pour des tests rapides et déterministes.
    AppConfig.initialize(
      const AppConfig(
        environment: AppEnvironment.development,
        apiBaseUrl: 'https://api.test.kadjane.app/v1',
        useMockData: true,
        networkLatency: Duration.zero,
        enableVerboseLogs: false,
      ),
    );
    db = MockDatabase();
    audit = MockAuditRepository(db);
    tontines = MockTontineRepository(db, audit);
    contributions = MockContributionRepository(db, audit);
    draws = MockDrawRepository(db, audit, SeededRandomSource(seed));
    payouts = MockPayoutRepository(db, audit);
  }

  late final MockDatabase db;
  late final MockAuditRepository audit;
  late final MockTontineRepository tontines;
  late final MockContributionRepository contributions;
  late final MockDrawRepository draws;
  late final MockPayoutRepository payouts;

  /// Tontine de démonstration en mode « tirage à chaque période ».
  Tontine get monthlyDrawTontine => db.tontines.firstWhere(
    (Tontine t) =>
        t.allocationMode == AllocationMode.monthlyDraw &&
        t.status == TontineStatus.active,
  );

  /// Tontine de démonstration en mode « ordre complet ».
  Tontine get fullOrderTontine => db.tontines.firstWhere(
    (Tontine t) => t.allocationMode == AllocationMode.fullOrderDraw,
  );

  /// Cycle en cours de la tontine principale (cotisations incomplètes).
  TontineCycle get currentCycle {
    final DateTime now = DateTime.now();
    return db
        .cyclesOf(monthlyDrawTontine.id)
        .firstWhere(
          (TontineCycle c) =>
              !now.isBefore(c.periodStart) && !now.isAfter(c.periodEnd),
        );
  }

  /// Administrateur de l'organisation principale.
  OrganizationMember get admin => db
      .membersOf(monthlyDrawTontine.organizationId)
      .firstWhere((OrganizationMember m) => m.role == OrgRole.admin);

  /// Trésorier de l'organisation principale.
  OrganizationMember get treasurer => db
      .membersOf(monthlyDrawTontine.organizationId)
      .firstWhere((OrganizationMember m) => m.role == OrgRole.treasurer);
}
