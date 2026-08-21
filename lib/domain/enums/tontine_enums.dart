/// Cycle de vie d'une tontine.
enum TontineStatus {
  draft('draft'),
  pending('pending'),
  active('active'),
  suspended('suspended'),
  completed('completed'),
  cancelled('cancelled');

  const TontineStatus(this.code);

  final String code;

  bool get isOpen =>
      this == TontineStatus.active || this == TontineStatus.pending;

  bool get isFinished =>
      this == TontineStatus.completed || this == TontineStatus.cancelled;

  static TontineStatus fromCode(String value) =>
      TontineStatus.values.firstWhere(
        (TontineStatus s) => s.code == value,
        orElse: () => TontineStatus.draft,
      );
}

/// Périodicité des cotisations.
enum TontineFrequency {
  weekly('weekly'),
  biweekly('biweekly'),
  monthly('monthly'),
  custom('custom');

  const TontineFrequency(this.code);

  final String code;

  static TontineFrequency fromCode(String value) =>
      TontineFrequency.values.firstWhere(
        (TontineFrequency f) => f.code == value,
        orElse: () => TontineFrequency.monthly,
      );
}

/// Mode d'attribution de la cagnotte.
enum AllocationMode {
  /// Mode A : un tirage par période parmi les membres non encore bénéficiaires.
  monthlyDraw('monthly_draw'),

  /// Mode B : un tirage unique qui fixe l'ordre complet de passage.
  fullOrderDraw('full_order_draw'),

  /// Mode C : ordre défini manuellement par l'administrateur.
  manualOrder('manual_order');

  const AllocationMode(this.code);

  final String code;

  /// Vrai si l'ordre de passage est connu dès le départ (modes B et C).
  bool get hasPredefinedOrder => this != AllocationMode.monthlyDraw;

  static AllocationMode fromCode(String value) =>
      AllocationMode.values.firstWhere(
        (AllocationMode m) => m.code == value,
        orElse: () => AllocationMode.monthlyDraw,
      );
}

/// État d'un cycle (une période de cotisation).
enum CycleStatus {
  upcoming('upcoming'),
  collecting('collecting'),
  readyForDraw('ready_for_draw'),
  drawn('drawn'),
  paidOut('paid_out'),
  closed('closed');

  const CycleStatus(this.code);

  final String code;

  bool get hasBeneficiary =>
      this == CycleStatus.drawn ||
      this == CycleStatus.paidOut ||
      this == CycleStatus.closed;

  static CycleStatus fromCode(String value) => CycleStatus.values.firstWhere(
    (CycleStatus s) => s.code == value,
    orElse: () => CycleStatus.upcoming,
  );
}
