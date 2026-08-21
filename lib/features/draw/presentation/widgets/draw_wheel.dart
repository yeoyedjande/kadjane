import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Roue de tirage.
///
/// La roue **n'a aucune influence sur le résultat** : elle reçoit l'angle final
/// calculé à partir du gagnant déjà déterminé par le moteur de tirage, et se
/// contente de l'afficher.
class DrawWheel extends StatelessWidget {
  const DrawWheel({
    required this.labels,
    required this.rotation,
    required this.colors,
    super.key,
    this.size = 300,
  });

  final List<String> labels;
  final Animation<double> rotation;
  final List<Color> colors;
  final double size;

  /// Angle final pour que le secteur [winnerIndex] s'arrête sous le repère.
  ///
  /// [turns] tours complets sont ajoutés pour l'effet visuel.
  static double targetAngleFor({
    required int winnerIndex,
    required int count,
    int turns = 5,
  }) {
    if (count == 0) {
      return 0;
    }
    final double step = 2 * math.pi / count;
    return 2 * math.pi * turns - (winnerIndex + 0.5) * step;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 18,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned(
            top: 16,
            child: AnimatedBuilder(
              animation: rotation,
              builder: (BuildContext context, Widget? child) => CustomPaint(
                size: Size.square(size),
                painter: _WheelPainter(
                  labels: labels,
                  rotation: rotation.value,
                  colors: colors,
                  borderColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ),
          // Repère fixe : le secteur qui s'arrête ici est le bénéficiaire.
          CustomPaint(
            size: const Size(26, 22),
            painter: _PointerPainter(
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.labels,
    required this.rotation,
    required this.colors,
    required this.borderColor,
  });

  final List<String> labels;
  final double rotation;
  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) {
      return;
    }
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final double step = 2 * math.pi / labels.length;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < labels.length; i++) {
      final double start = -math.pi / 2 + i * step + rotation;
      canvas.drawArc(
        rect,
        start,
        step,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        rect,
        start,
        step,
        true,
        Paint()
          ..color = borderColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Nom du participant, écrit le long du rayon.
      final double middle = start + step / 2;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(middle);
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _shorten(labels[i]),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: radius - 34);
      painter.paint(canvas, Offset(radius - painter.width - 14, -6));
      canvas.restore();
    }

    // Moyeu central.
    canvas
      ..drawCircle(center, radius * 0.22, Paint()..color = borderColor)
      ..drawCircle(
        center,
        radius * 0.22,
        Paint()
          ..color = colors.first.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  static String _shorten(String value) {
    final List<String> parts = value.split(' ');
    if (parts.length <= 2) {
      return value;
    }
    return '${parts.first} ${parts[1]}';
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.labels != labels;
}

class _PointerPainter extends CustomPainter {
  _PointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bouton central « Lancer le tirage ».
class DrawSpinButton extends StatelessWidget {
  const DrawSpinButton({
    required this.label,
    required this.onPressed,
    required this.isSpinning,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null
          ? Theme.of(context).disabledColor
          : Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isSpinning ? null : onPressed,
        child: SizedBox(
          height: 108,
          width: 108,
          child: Center(
            child: isSpinning
                ? const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
