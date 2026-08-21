import 'package:kadjane/core/utils/period_label.dart';

/// Formatage centralisé des dates.
///
/// Volontairement sans `DateFormat` : les libellés doivent rester disponibles
/// dans la couche données et dans les tests, sans initialisation de locale.
class DateFormatter {
  const DateFormatter._();

  /// `18/08/2026`
  static String date(DateTime value, [String locale = 'fr']) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';

  /// `18/08/2026 14:32`
  static String dateTime(DateTime value, [String locale = 'fr']) =>
      '${date(value, locale)} ${time(value, locale)}';

  /// `14:32`
  static String time(DateTime value, [String locale = 'fr']) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  /// `18 août`
  static String dayMonth(DateTime value, [String locale = 'fr']) =>
      '${value.day} ${PeriodLabel.month(value, locale: locale).toLowerCase()}';

  /// Libellé de période d'un cycle : `Août 2026`.
  static String periodLabel(DateTime value, [String locale = 'fr']) =>
      PeriodLabel.monthYear(value, locale: locale);

  /// Libellé court pour les graphiques : `Août`.
  static String monthShort(DateTime value, [String locale = 'fr']) =>
      PeriodLabel.monthShort(value, locale: locale);

  static String _two(int value) => value.toString().padLeft(2, '0');
}
