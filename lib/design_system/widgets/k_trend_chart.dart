import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/domain/enums/currency.dart';

/// Point d'un graphique d'évolution.
class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.value,
    required this.reference,
  });

  final String label;

  /// Montant collecté.
  final double value;

  /// Montant attendu (ligne de référence).
  final double reference;
}

/// Graphique d'évolution des cotisations.
///
/// Peint à la main : aucune dépendance externe, couleurs issues du thème,
/// rendu identique en clair et en sombre.
class KTrendChart extends StatelessWidget {
  const KTrendChart({
    required this.points,
    required this.currency,
    super.key,
    this.height = 170,
  });

  final List<ChartPoint> points;
  final Currency currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            context.l10n.commonNoResults,
            style: context.text.bodySmall,
          ),
        ),
      );
    }

    final double maxValue = points
        .map((ChartPoint p) => p.reference > p.value ? p.reference : p.value)
        .reduce((double a, double b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Legend(
              color: context.colors.chartLine,
              label: context.l10n.contributionsCollected,
            ),
            const SizedBox(width: KSpacing.lg),
            _Legend(
              color: context.colors.textTertiary,
              label: context.l10n.contributionsExpected,
              dashed: true,
            ),
            const Spacer(),
            Text(
              MoneyFormatter.compact(maxValue, currency),
              style: context.text.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: KSpacing.md),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              points: points,
              maxValue: maxValue <= 0 ? 1 : maxValue,
              lineColor: context.colors.chartLine,
              areaColor: context.colors.chartArea,
              referenceColor: context.colors.textTertiary,
              gridColor: context.colors.divider,
              labelStyle:
                  context.text.labelSmall ?? const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: KSpacing.xs),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.maxValue,
    required this.lineColor,
    required this.areaColor,
    required this.referenceColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<ChartPoint> points;
  final double maxValue;
  final Color lineColor;
  final Color areaColor;
  final Color referenceColor;
  final Color gridColor;
  final TextStyle labelStyle;

  static const double _labelHeight = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height - _labelHeight;
    final double stepX = points.length == 1
        ? 0
        : size.width / (points.length - 1);

    // Lignes horizontales de repère.
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset positionOf(int index, double value) {
      final double x = points.length == 1 ? size.width / 2 : stepX * index;
      final double ratio = (value / maxValue).clamp(0.0, 1.0);
      return Offset(x, chartHeight - chartHeight * ratio);
    }

    // Aire + courbe du collecté.
    final Path linePath = Path();
    final Path areaPath = Path()..moveTo(0, chartHeight);
    for (int i = 0; i < points.length; i++) {
      final Offset point = positionOf(i, points[i].value);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
        areaPath.lineTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
        areaPath.lineTo(point.dx, point.dy);
      }
    }
    areaPath
      ..lineTo(size.width, chartHeight)
      ..close();

    canvas.drawPath(areaPath, Paint()..color = areaColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Ligne pointillée de l'attendu.
    final Paint referencePaint = Paint()
      ..color = referenceColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      final Offset a = positionOf(i, points[i].reference);
      final Offset b = positionOf(i + 1, points[i + 1].reference);
      _drawDashedLine(canvas, a, b, referencePaint);
    }

    // Points et libellés.
    for (int i = 0; i < points.length; i++) {
      final Offset point = positionOf(i, points[i].value);
      canvas
        ..drawCircle(point, 4.5, Paint()..color = lineColor)
        ..drawCircle(point, 2, Paint()..color = const Color(0xFFFFFFFF));

      final TextPainter painter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: stepX == 0 ? size.width : stepX + 24);
      final double dx = (point.dx - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(dx, chartHeight + 6));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const double dashWidth = 5;
    const double gap = 4;
    final double distance = (to - from).distance;
    if (distance == 0) {
      return;
    }
    final Offset direction = (to - from) / distance;
    double drawn = 0;
    while (drawn < distance) {
      final double end = (drawn + dashWidth).clamp(0.0, distance);
      canvas.drawLine(from + direction * drawn, from + direction * end, paint);
      drawn = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.lineColor != lineColor;
}
