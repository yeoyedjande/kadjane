/// Ligne de rapport par tontine.
class TontineReportLine {
  const TontineReportLine({
    required this.tontineId,
    required this.tontineName,
    required this.expected,
    required this.collected,
    required this.distributed,
    required this.participants,
  });

  final String tontineId;
  final String tontineName;
  final double expected;
  final double collected;
  final double distributed;
  final int participants;

  double get unpaid => (expected - collected).clamp(0, double.infinity);

  double get recoveryRate =>
      expected <= 0 ? 0 : (collected / expected).clamp(0, 1);
}

/// Synthèse des rapports de l'organisation.
class ReportSnapshot {
  const ReportSnapshot({
    required this.totalExpected,
    required this.totalCollected,
    required this.totalDistributed,
    required this.membersCount,
    required this.activeTontines,
    required this.lines,
  });

  final double totalExpected;
  final double totalCollected;
  final double totalDistributed;
  final int membersCount;
  final int activeTontines;
  final List<TontineReportLine> lines;

  double get unpaid =>
      (totalExpected - totalCollected).clamp(0, double.infinity);

  double get recoveryRate =>
      totalExpected <= 0 ? 0 : (totalCollected / totalExpected).clamp(0, 1);
}

/// Formats d'export proposés.
enum ReportFormat { pdf, excel }

abstract interface class ReportRepository {
  Future<ReportSnapshot> load(String organizationId);

  /// Génère un export et retourne son chemin/URL.
  ///
  /// TODO(api): génération réelle côté backend (GET /reports/export).
  Future<String> export({
    required String organizationId,
    required ReportFormat format,
  });
}
