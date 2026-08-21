/// Devises supportées par Kadjane.
///
/// Le franc CFA est la devise de référence du MVP, mais l'architecture est
/// prête pour l'EUR, l'USD ou le CAD (nombre de décimales et position du
/// symbole configurables).
enum Currency {
  xof(code: 'XOF', symbol: 'FCFA', decimals: 0, symbolOnLeft: false),
  eur(code: 'EUR', symbol: '€', decimals: 2, symbolOnLeft: false),
  usd(code: 'USD', symbol: '\$', decimals: 2, symbolOnLeft: true),
  cad(code: 'CAD', symbol: 'CA\$', decimals: 2, symbolOnLeft: true);

  const Currency({
    required this.code,
    required this.symbol,
    required this.decimals,
    required this.symbolOnLeft,
  });

  final String code;
  final String symbol;
  final int decimals;
  final bool symbolOnLeft;

  /// Séparateur de milliers : espace pour les zones XOF/EUR, virgule ailleurs.
  String get groupSeparator => symbolOnLeft ? ',' : ' ';

  String get decimalSeparator => symbolOnLeft ? '.' : ',';

  static Currency fromCode(String value) {
    return Currency.values.firstWhere(
      (Currency c) => c.code == value.toUpperCase(),
      orElse: () => Currency.xof,
    );
  }
}
