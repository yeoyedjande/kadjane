import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';

/// Indicateur de chargement centré.
class KLoadingView extends StatelessWidget {
  const KLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: KSpacing.lg),
            Text(message!, style: context.text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// État vide : jamais d'écran blanc.
class KEmptyState extends StatelessWidget {
  const KEmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(KSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: context.colors.textTertiary),
            ),
            const SizedBox(height: KSpacing.lg),
            Text(
              title ?? context.l10n.commonEmptyTitle,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: KSpacing.xl),
              KButton(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur avec possibilité de réessayer.
class KErrorState extends StatelessWidget {
  const KErrorState({required this.error, super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(KSpacing.lg),
              decoration: BoxDecoration(
                color: context.colors.dangerSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 30,
                color: context.colors.danger,
              ),
            ),
            const SizedBox(height: KSpacing.lg),
            Text(
              context.l10n.commonErrorTitle,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              ErrorMapper.message(context.l10n, error),
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: KSpacing.xl),
              KButton.secondary(
                label: context.l10n.commonRetry,
                onPressed: onRetry,
                icon: Icons.refresh,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau hors ligne affiché en haut des écrans.
class KOfflineBanner extends StatelessWidget {
  const KOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.warningSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.lg,
        vertical: KSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.wifi_off_outlined,
            size: KSizes.iconSm,
            color: context.colors.warning,
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.commonOfflineTitle,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rendu unifié d'un [AsyncValue] : chargement, erreur, vide, données.
///
/// Grâce à ce widget, aucun écran ne peut afficher une page blanche.
class KAsyncView<T> extends StatelessWidget {
  const KAsyncView({
    required this.value,
    required this.builder,
    super.key,
    this.onRetry,
    this.isEmpty,
    this.emptyBuilder,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => KLoadingView(message: loadingMessage),
      error: (Object error, StackTrace _) =>
          KErrorState(error: error, onRetry: onRetry),
      data: (T data) {
        if (isEmpty != null && isEmpty!(data)) {
          return emptyBuilder?.call(context) ??
              KEmptyState(message: context.l10n.commonNoResults);
        }
        return builder(data);
      },
    );
  }
}
