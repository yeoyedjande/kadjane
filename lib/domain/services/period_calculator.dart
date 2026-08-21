import 'package:kadjane/domain/enums/tontine_enums.dart';

/// Bornes d'une période de cotisation.
class PeriodBounds {
  const PeriodBounds({
    required this.start,
    required this.end,
    required this.dueDate,
  });

  final DateTime start;
  final DateTime end;
  final DateTime dueDate;
}

/// Calcule les périodes d'une tontine selon sa fréquence.
///
/// `bimensuelle` = deux périodes par mois (1–15, 16–fin de mois).
class PeriodCalculator {
  const PeriodCalculator();

  PeriodBounds boundsFor({
    required DateTime startDate,
    required TontineFrequency frequency,
    required int index,
    int dueDayOfPeriod = 5,
    int? customPeriodDays,
  }) {
    switch (frequency) {
      case TontineFrequency.monthly:
        return _monthly(startDate, index, dueDayOfPeriod);
      case TontineFrequency.biweekly:
        return _biweekly(startDate, index);
      case TontineFrequency.weekly:
        return _fixedLength(startDate, index, 7);
      case TontineFrequency.custom:
        return _fixedLength(startDate, index, customPeriodDays ?? 30);
    }
  }

  /// Génère [count] périodes consécutives à partir de [startDate].
  List<PeriodBounds> generate({
    required DateTime startDate,
    required TontineFrequency frequency,
    required int count,
    int dueDayOfPeriod = 5,
    int? customPeriodDays,
  }) {
    return List<PeriodBounds>.generate(
      count,
      (int index) => boundsFor(
        startDate: startDate,
        frequency: frequency,
        index: index,
        dueDayOfPeriod: dueDayOfPeriod,
        customPeriodDays: customPeriodDays,
      ),
    );
  }

  PeriodBounds _monthly(DateTime startDate, int index, int dueDay) {
    final DateTime start = DateTime(startDate.year, startDate.month + index);
    final DateTime end = DateTime(start.year, start.month + 1, 0, 23, 59, 59);
    final int lastDay = end.day;
    final DateTime due = DateTime(
      start.year,
      start.month,
      dueDay.clamp(1, lastDay),
      23,
      59,
      59,
    );
    return PeriodBounds(start: start, end: end, dueDate: due);
  }

  PeriodBounds _biweekly(DateTime startDate, int index) {
    final int monthOffset = index ~/ 2;
    final bool secondHalf = index.isOdd;
    final DateTime monthStart = DateTime(
      startDate.year,
      startDate.month + monthOffset,
    );
    final DateTime monthEnd = DateTime(
      monthStart.year,
      monthStart.month + 1,
      0,
      23,
      59,
      59,
    );
    if (!secondHalf) {
      final DateTime end = DateTime(
        monthStart.year,
        monthStart.month,
        15,
        23,
        59,
        59,
      );
      return PeriodBounds(start: monthStart, end: end, dueDate: end);
    }
    final DateTime start = DateTime(monthStart.year, monthStart.month, 16);
    return PeriodBounds(start: start, end: monthEnd, dueDate: monthEnd);
  }

  PeriodBounds _fixedLength(DateTime startDate, int index, int lengthInDays) {
    final DateTime start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).add(Duration(days: lengthInDays * index));
    final DateTime end = start
        .add(Duration(days: lengthInDays))
        .subtract(const Duration(seconds: 1));
    return PeriodBounds(start: start, end: end, dueDate: end);
  }
}
