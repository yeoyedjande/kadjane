import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/domain/enums/currency.dart';

/// Barre de progression arrondie et animée.
class KProgressBar extends StatelessWidget {
  const KProgressBar({
    required this.value,
    super.key,
    this.color,
    this.height = KSizes.progressBar,
  });

  /// Valeur entre 0 et 1.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: context.colors.surfaceMuted),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return AnimatedContainer(
                duration: KDurations.slow,
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  color: color ?? context.scheme.primary,
                  borderRadius: BorderRadius.circular(height),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Progression d'une collecte : « 850 000 / 1 000 000 FCFA — 85 % ».
class KAmountProgress extends StatelessWidget {
  const KAmountProgress({
    required this.collected,
    required this.expected,
    required this.currency,
    super.key,
    this.label,
    this.compactAmounts = false,
  });

  final double collected;
  final double expected;
  final Currency currency;
  final String? label;
  final bool compactAmounts;

  @override
  Widget build(BuildContext context) {
    final double ratio = expected <= 0 ? 0 : (collected / expected);
    final String collectedText = compactAmounts
        ? MoneyFormatter.compact(collected, currency, showSymbol: false)
        : MoneyFormatter.format(collected, currency, showSymbol: false);
    final String expectedText = compactAmounts
        ? MoneyFormatter.compact(expected, currency)
        : MoneyFormatter.format(expected, currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!, style: context.text.bodySmall),
          const SizedBox(height: KSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                '$collectedText / $expectedText',
                style: context.text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              MoneyFormatter.percent(ratio),
              style: context.text.titleSmall?.copyWith(
                color: ratio >= 1
                    ? context.colors.success
                    : context.colors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: KSpacing.sm),
        KProgressBar(
          value: ratio,
          color: ratio >= 1 ? context.colors.success : null,
        ),
      ],
    );
  }
}

/// Indicateur d'étapes (cotisations → cagnotte → tirage → versement).
class KStepTrail extends StatelessWidget {
  const KStepTrail({
    required this.steps,
    required this.currentIndex,
    super.key,
  });

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(steps.length, (int index) {
        final bool done = index < currentIndex;
        final bool active = index == currentIndex;
        final Color color = done
            ? context.colors.success
            : active
            ? context.colors.brand
            : context.colors.textTertiary;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done || active
                        ? color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: done
                      ? Icon(Icons.check, size: 13, color: color)
                      : null,
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 2,
                    height: 26,
                    color: done ? color : context.colors.divider,
                  ),
              ],
            ),
            const SizedBox(width: KSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                steps[index],
                style: active
                    ? context.text.titleSmall
                    : context.text.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        );
      }),
    );
  }
}
