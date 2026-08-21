import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/design_system/theme/app_colors.dart';
import 'package:kadjane/features/draw/presentation/widgets/draw_wheel.dart';

void main() {
  /// Angle du centre du secteur [index] une fois la roue tournée de [rotation].
  double sectorCenter(int index, int count, double rotation) =>
      -math.pi / 2 + (index + 0.5) * (2 * math.pi / count) + rotation;

  group('Alignement de la roue', () {
    test('le secteur gagnant s\'arrête exactement sous la flèche', () {
      for (final int count in <int>[2, 3, 7, 12]) {
        for (int winner = 0; winner < count; winner++) {
          final double target = DrawWheel.targetAngleFor(
            winnerIndex: winner,
            count: count,
          );
          final double center = sectorCenter(winner, count, target);
          // La flèche est en haut, soit -pi/2 (modulo un tour complet).
          final double offset = (center + math.pi / 2) % (2 * math.pi);
          expect(
            math.min(offset, 2 * math.pi - offset),
            closeTo(0, 1e-9),
            reason: 'count=$count winner=$winner',
          );
        }
      }
    });

    test('la rotation comporte plusieurs tours complets', () {
      final double target = DrawWheel.targetAngleFor(
        winnerIndex: 0,
        count: 8,
        turns: 5,
      );

      expect(target, greaterThan(4 * 2 * math.pi));
    });

    test('une roue vide ne produit aucune rotation', () {
      expect(DrawWheel.targetAngleFor(winnerIndex: 0, count: 0), 0);
    });
  });

  testWidgets('la roue se redessine pendant l\'animation', (
    WidgetTester tester,
  ) async {
    final AnimationController controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 600),
    );
    addTearDown(controller.dispose);

    final Animation<double> rotation = Tween<double>(
      begin: 0,
      end: DrawWheel.targetAngleFor(winnerIndex: 2, count: 6),
    ).animate(controller);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DrawWheel(
              labels: const <String>[
                'Awa',
                'YEO',
                'Serge',
                'Fatou',
                'Ibrahim',
                'Mariam',
              ],
              rotation: rotation,
              colors: KadjaneColors.light.wheelColors,
            ),
          ),
        ),
      ),
    );

    expect(rotation.value, 0);
    controller.forward();
    // Le premier pump démarre le ticker, le suivant fait avancer le temps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final double midway = rotation.value;
    expect(midway, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 400));
    expect(rotation.value, greaterThan(midway));
    expect(rotation.isCompleted || controller.isCompleted, isTrue);
  });
}
