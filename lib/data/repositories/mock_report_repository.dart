import 'package:kadjane/data/mock/mock_database.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/report_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Rapports agrégés.
///
/// TODO(api): remplacer par `RestReportRepository` et brancher l'export réel
/// (PDF / Excel) généré côté serveur.
class MockReportRepository implements ReportRepository {
  MockReportRepository(this._db, [this._rules = const TontineRulesService()]);

  final MockDatabase _db;
  final TontineRulesService _rules;

  @override
  Future<ReportSnapshot> load(String organizationId) => _db.withLatency(() {
    final DateTime now = DateTime.now();
    final List<Tontine> tontines = _db.tontinesOf(organizationId);
    final List<TontineReportLine> lines = <TontineReportLine>[];
    double totalExpected = 0;
    double totalCollected = 0;
    double totalDistributed = 0;

    for (final Tontine tontine in tontines) {
      final List<TontineCycle> startedCycles = _db
          .cyclesOf(tontine.id)
          .where((TontineCycle c) => !c.periodStart.isAfter(now))
          .toList(growable: false);
      final double expected = startedCycles.fold<double>(
        0,
        (double sum, TontineCycle c) => sum + c.expectedAmount,
      );
      final double collected = _rules.collectedAmount(
        _db.contributionsOfTontine(tontine.id),
      );
      final double distributed = _db.payouts
          .where((Payout p) => p.tontineId == tontine.id && p.isPaid)
          .fold<double>(0, (double sum, Payout p) => sum + p.amount);

      totalExpected += expected;
      totalCollected += collected;
      totalDistributed += distributed;

      lines.add(
        TontineReportLine(
          tontineId: tontine.id,
          tontineName: tontine.name,
          expected: expected,
          collected: collected,
          distributed: distributed,
          participants: _db.participantsOf(tontine.id).length,
        ),
      );
    }

    return ReportSnapshot(
      totalExpected: totalExpected,
      totalCollected: totalCollected,
      totalDistributed: totalDistributed,
      membersCount: _db.membersOf(organizationId).length,
      activeTontines: tontines
          .where((Tontine t) => t.status == TontineStatus.active)
          .length,
      lines: lines,
    );
  });

  @override
  Future<String> export({
    required String organizationId,
    required ReportFormat format,
  }) => _db.withLatency(() {
    final String extension = format == ReportFormat.pdf ? 'pdf' : 'xlsx';
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    // Export simulé : le backend renverra une URL signée.
    return 'kadjane_rapport_${organizationId}_$stamp.$extension';
  });
}
