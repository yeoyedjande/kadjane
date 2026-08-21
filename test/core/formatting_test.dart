import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/core/utils/validators.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/services/period_calculator.dart';

void main() {
  group('MoneyFormatter', () {
    test('formate le franc CFA sans décimale', () {
      expect(MoneyFormatter.format(50000, Currency.xof), '50 000 FCFA');
      expect(MoneyFormatter.format(1000000, Currency.xof), '1 000 000 FCFA');
      expect(MoneyFormatter.format(850000, Currency.xof), '850 000 FCFA');
      expect(MoneyFormatter.format(0, Currency.xof), '0 FCFA');
    });

    test('gère les montants négatifs et le masquage du symbole', () {
      expect(MoneyFormatter.format(-75000, Currency.xof), '-75 000 FCFA');
      expect(
        MoneyFormatter.format(50000, Currency.xof, showSymbol: false),
        '50 000',
      );
    });

    test('formate les devises à deux décimales', () {
      expect(MoneyFormatter.format(1234.5, Currency.eur), '1 234,50 €');
      expect(MoneyFormatter.format(1234.5, Currency.usd), r'$1,234.50');
    });

    test('produit une version compacte lisible', () {
      expect(MoneyFormatter.compact(1000000, Currency.xof), '1 M FCFA');
      expect(MoneyFormatter.compact(1200000, Currency.xof), '1,2 M FCFA');
      expect(MoneyFormatter.compact(850000, Currency.xof), '850 k FCFA');
      expect(MoneyFormatter.compact(750, Currency.xof), '750 FCFA');
    });

    test('affiche un pourcentage arrondi', () {
      expect(MoneyFormatter.percent(0.85), '85 %');
      expect(MoneyFormatter.percent(1), '100 %');
      expect(MoneyFormatter.percent(0), '0 %');
    });
  });

  group('DateFormatter', () {
    final DateTime date = DateTime(2026, 8, 18, 14, 32);

    test('formate dates et heures', () {
      expect(DateFormatter.date(date), '18/08/2026');
      expect(DateFormatter.dateTime(date), '18/08/2026 14:32');
      expect(DateFormatter.time(date), '14:32');
    });

    test('produit un libellé de période localisé', () {
      expect(DateFormatter.periodLabel(date), 'Août 2026');
      expect(DateFormatter.periodLabel(date, 'en'), 'August 2026');
    });
  });

  group('Validators', () {
    test('valide emails et téléphones', () {
      expect(Validators.isValidEmail('yeo@kadjane.app'), isTrue);
      expect(Validators.isValidEmail('yeo@kadjane'), isFalse);
      expect(Validators.isValidPhone('+225 07 00 00 00 01'), isTrue);
      expect(Validators.isValidPhone('123'), isFalse);
    });

    test('analyse les montants saisis', () {
      expect(Validators.parseAmount('50 000'), 50000);
      expect(Validators.parseAmount('50000,50'), 50000.5);
      expect(Validators.parseAmount('abc'), isNull);
      expect(Validators.isPositiveAmount('0'), isFalse);
    });
  });

  group('PeriodCalculator', () {
    const PeriodCalculator calculator = PeriodCalculator();

    test('découpe les périodes mensuelles', () {
      final List<PeriodBounds> bounds = calculator.generate(
        startDate: DateTime(2026, 3),
        frequency: TontineFrequency.monthly,
        count: 3,
        dueDayOfPeriod: 5,
      );

      expect(bounds.length, 3);
      expect(bounds.first.start, DateTime(2026, 3));
      expect(bounds.first.dueDate.day, 5);
      expect(bounds[1].start.month, 4);
      expect(bounds[2].start.month, 5);
      expect(bounds[2].end.day, 31);
    });

    test('découpe les périodes hebdomadaires', () {
      final List<PeriodBounds> bounds = calculator.generate(
        startDate: DateTime(2026, 3, 2),
        frequency: TontineFrequency.weekly,
        count: 2,
      );

      expect(bounds[1].start, DateTime(2026, 3, 9));
    });

    test('découpe deux périodes par mois en bimensuel', () {
      final List<PeriodBounds> bounds = calculator.generate(
        startDate: DateTime(2026, 3),
        frequency: TontineFrequency.biweekly,
        count: 4,
      );

      expect(bounds[0].end.day, 15);
      expect(bounds[1].start.day, 16);
      expect(bounds[2].start.month, 4);
    });
  });
}
