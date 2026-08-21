/// Sens d'une opération de caisse.
enum TransactionType {
  income('income'),
  expense('expense');

  const TransactionType(this.code);

  final String code;

  int get sign => this == TransactionType.income ? 1 : -1;

  static TransactionType fromCode(String value) =>
      TransactionType.values.firstWhere(
        (TransactionType t) => t.code == value,
        orElse: () => TransactionType.income,
      );
}

/// Catégories de caisse par défaut (extensible côté organisation).
enum TransactionCategory {
  contribution('contribution'),
  payout('payout'),
  donation('donation'),
  fee('fee'),
  event('event'),
  socialAid('social_aid'),
  other('other');

  const TransactionCategory(this.code);

  final String code;

  static TransactionCategory fromCode(String value) =>
      TransactionCategory.values.firstWhere(
        (TransactionCategory c) => c.code == value,
        orElse: () => TransactionCategory.other,
      );
}
