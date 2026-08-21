import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_button.dart';

/// Boîtes de dialogue de confirmation.
///
/// Toute opération critique (tirage, annulation, invalidation, déconnexion)
/// passe par ici.
class KConfirmDialog extends StatelessWidget {
  const KConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    super.key,
    this.cancelLabel,
    this.isDestructive = false,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;
  final IconData? icon;

  /// Retourne `true` si l'utilisateur confirme.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => KConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = isDestructive
        ? context.colors.danger
        : context.colors.brand;
    return AlertDialog(
      icon: icon == null
          ? null
          : Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent),
            ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(
        KSpacing.xl,
        0,
        KSpacing.xl,
        KSpacing.xl,
      ),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: KButton.secondary(
                label: cancelLabel ?? context.l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: isDestructive
                  ? KButton.danger(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    )
                  : KButton(
                      label: confirmLabel,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Demande un motif à l'utilisateur (forçage de tirage, annulation...).
class KReasonDialog extends StatefulWidget {
  const KReasonDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.confirmLabel,
    super.key,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final String confirmLabel;

  /// Retourne le motif saisi, ou `null` si l'utilisateur annule.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String fieldLabel,
    required String confirmLabel,
  }) => showDialog<String>(
    context: context,
    builder: (BuildContext context) => KReasonDialog(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
    ),
  );

  @override
  State<KReasonDialog> createState() => _KReasonDialogState();
}

class _KReasonDialogState extends State<KReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.message, style: context.text.bodyMedium),
          const SizedBox(height: KSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(labelText: widget.fieldLabel),
            onChanged: (String value) =>
                setState(() => _isValid = value.trim().length >= 3),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        KSpacing.xl,
        0,
        KSpacing.xl,
        KSpacing.xl,
      ),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: KButton.secondary(
                label: context.l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: KButton(
                label: widget.confirmLabel,
                onPressed: _isValid
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Feuille modale standard (formulaires courts).
Future<T?> showKSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}
