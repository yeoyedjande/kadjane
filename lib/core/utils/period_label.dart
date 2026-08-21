/// Libellés de mois, sans dépendance aux données de locale d'intl.
///
/// Ils sont utilisés jusque dans la couche données (libellé figé d'un tirage),
/// où l'initialisation des locales n'est pas garantie.
class PeriodLabel {
  const PeriodLabel._();

  static const List<String> _fr = <String>[
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  static const List<String> _en = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static List<String> _months(String locale) =>
      locale.startsWith('en') ? _en : _fr;

  /// `Août 2026`
  static String monthYear(DateTime date, {String locale = 'fr'}) =>
      '${_months(locale)[date.month - 1]} ${date.year}';

  /// `Août`
  static String month(DateTime date, {String locale = 'fr'}) =>
      _months(locale)[date.month - 1];

  /// `Août` tronqué à 3 lettres pour les graphiques.
  static String monthShort(DateTime date, {String locale = 'fr'}) {
    final String name = month(date, locale: locale);
    return name.length <= 4 ? name : name.substring(0, 3);
  }
}
