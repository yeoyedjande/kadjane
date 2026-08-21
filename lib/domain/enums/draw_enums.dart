/// État d'une session de tirage.
///
/// Un tirage validé n'est jamais supprimé : il peut seulement être annulé ou
/// invalidé, et chaque changement laisse une trace dans le journal d'audit.
enum DrawStatus {
  scheduled('scheduled'),
  completed('completed'),
  cancelled('cancelled'),
  invalidated('invalidated');

  const DrawStatus(this.code);

  final String code;

  /// Un tirage validé fait foi tant qu'il n'a pas été annulé/invalidé.
  bool get isBinding => this == DrawStatus.completed;

  static DrawStatus fromCode(String value) => DrawStatus.values.firstWhere(
    (DrawStatus s) => s.code == value,
    orElse: () => DrawStatus.scheduled,
  );
}

/// Origine de la désignation d'un bénéficiaire.
enum BeneficiarySource {
  periodicDraw('periodic_draw'),
  orderDraw('order_draw'),
  manualOrder('manual_order');

  const BeneficiarySource(this.code);

  final String code;

  static BeneficiarySource fromCode(String value) =>
      BeneficiarySource.values.firstWhere(
        (BeneficiarySource s) => s.code == value,
        orElse: () => BeneficiarySource.periodicDraw,
      );
}
