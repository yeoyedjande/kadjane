/// État d'une cotisation.
enum ContributionStatus {
  pending('pending'),
  confirmed('confirmed'),
  rejected('rejected'),
  cancelled('cancelled');

  const ContributionStatus(this.code);

  final String code;

  /// Seules les cotisations confirmées entrent dans le montant collecté.
  bool get countsAsCollected => this == ContributionStatus.confirmed;

  static ContributionStatus fromCode(String value) =>
      ContributionStatus.values.firstWhere(
        (ContributionStatus s) => s.code == value,
        orElse: () => ContributionStatus.pending,
      );
}

/// Moyens de paiement acceptés.
enum PaymentMethod {
  wave('wave'),
  orangeMoney('orange_money'),
  mtnMomo('mtn_momo'),
  moovMoney('moov_money'),
  bankTransfer('bank_transfer'),
  cash('cash'),
  other('other');

  const PaymentMethod(this.code);

  final String code;

  bool get isMobileMoney =>
      this == PaymentMethod.wave ||
      this == PaymentMethod.orangeMoney ||
      this == PaymentMethod.mtnMomo ||
      this == PaymentMethod.moovMoney;

  static PaymentMethod fromCode(String value) =>
      PaymentMethod.values.firstWhere(
        (PaymentMethod m) => m.code == value,
        orElse: () => PaymentMethod.other,
      );
}

/// État du versement de la cagnotte au bénéficiaire.
enum PayoutStatus {
  pending('pending'),
  processing('processing'),
  paid('paid'),
  failed('failed');

  const PayoutStatus(this.code);

  final String code;

  static PayoutStatus fromCode(String value) => PayoutStatus.values.firstWhere(
    (PayoutStatus s) => s.code == value,
    orElse: () => PayoutStatus.pending,
  );
}
