import 'package:kadjane/domain/enums/currency.dart';

/// Formatage centralisé des montants.
///
/// Exemples (XOF) : `50 000 FCFA`, `1 000 000 FCFA`.
/// Aucun écran ne doit formater un montant manuellement.
class MoneyFormatter {
  const MoneyFormatter._();

  /// Formate un montant avec sa devise : `50 000 FCFA`.
  static String format(
    num amount,
    Currency currency, {
    bool showSymbol = true,
  }) {
    final String body = _formatNumber(amount, currency);
    if (!showSymbol) {
      return body;
    }
    return currency.symbolOnLeft
        ? '${currency.symbol}$body'
        : '$body ${currency.symbol}';
  }

  /// Formate un montant de façon compacte : `1,2 M FCFA`, `850 k FCFA`.
  static String compact(
    num amount,
    Currency currency, {
    bool showSymbol = true,
  }) {
    final num abs = amount.abs();
    final String sign = amount < 0 ? '-' : '';
    String body;
    if (abs >= 1000000) {
      body = '$sign${_oneDecimal(abs / 1000000, currency)} M';
    } else if (abs >= 1000) {
      body = '$sign${_oneDecimal(abs / 1000, currency)} k';
    } else {
      body = _formatNumber(amount, currency);
    }
    if (!showSymbol) {
      return body;
    }
    return currency.symbolOnLeft
        ? '${currency.symbol}$body'
        : '$body ${currency.symbol}';
  }

  /// Pourcentage arrondi : `85 %`.
  static String percent(double ratio) {
    final double clamped = ratio.isFinite ? ratio.clamp(0.0, 10.0) : 0.0;
    return '${(clamped * 100).round()} %';
  }

  static String _oneDecimal(double value, Currency currency) {
    final String raw = value.toStringAsFixed(1);
    final String trimmed = raw.endsWith('.0')
        ? raw.substring(0, raw.length - 2)
        : raw;
    return trimmed.replaceAll('.', currency.decimalSeparator);
  }

  static String _formatNumber(num amount, Currency currency) {
    final bool negative = amount < 0;
    final num abs = amount.abs();
    final String fixed = abs.toStringAsFixed(currency.decimals);
    final List<String> parts = fixed.split('.');
    final String grouped = _group(parts.first, currency.groupSeparator);
    final String result = parts.length > 1
        ? '$grouped${currency.decimalSeparator}${parts[1]}'
        : grouped;
    return negative ? '-$result' : result;
  }

  static String _group(String digits, String separator) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(separator);
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
