import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Champ de saisie standard, avec libellé au-dessus du champ.
class KTextField extends StatelessWidget {
  const KTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.inputFormatters,
    this.initialValue,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            bottom: KSpacing.sm,
            left: KSpacing.xs,
          ),
          child: Text(label, style: context.text.labelMedium),
        ),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: obscureText ? 1 : maxLines,
          enabled: enabled,
          autofocus: autofocus,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          style: context.text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: KSizes.iconMd),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Champ mot de passe avec bascule de visibilité.
class KPasswordField extends StatefulWidget {
  const KPasswordField({
    required this.label,
    required this.controller,
    super.key,
    this.validator,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  @override
  State<KPasswordField> createState() => _KPasswordFieldState();
}

class _KPasswordFieldState extends State<KPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return KTextField(
      label: widget.label,
      controller: widget.controller,
      obscureText: _obscured,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      prefixIcon: Icons.lock_outline,
      suffix: IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: KSizes.iconMd,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}

/// Liste déroulante générique.
class KDropdownField<T> extends StatelessWidget {
  const KDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    super.key,
    this.hint,
    this.itemIcon,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final IconData Function(T item)? itemIcon;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            bottom: KSpacing.sm,
            left: KSpacing.xs,
          ),
          child: Text(label, style: context.text.labelMedium),
        ),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          borderRadius: KRadius.field,
          style: context.text.bodyLarge,
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Row(
                    children: <Widget>[
                      if (itemIcon != null) ...<Widget>[
                        Icon(itemIcon!(item), size: KSizes.iconSm),
                        const SizedBox(width: KSpacing.sm),
                      ],
                      Expanded(
                        child: Text(
                          itemLabel(item),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Sélecteur de date affiché comme un champ.
class KDateField extends StatelessWidget {
  const KDateField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            bottom: KSpacing.sm,
            left: KSpacing.xs,
          ),
          child: Text(label, style: context.text.labelMedium),
        ),
        InkWell(
          borderRadius: KRadius.field,
          onTap: () async {
            final DateTime now = DateTime.now();
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: firstDate ?? DateTime(now.year - 5),
              lastDate: lastDate ?? DateTime(now.year + 5),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.event_outlined, size: KSizes.iconMd),
            ),
            child: Text(
              value == null
                  ? context.l10n.commonSelect
                  : DateFormatter.date(value!, context.localeCode),
              style: context.text.bodyLarge?.copyWith(
                color: value == null ? context.colors.textTertiary : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Champ de recherche compact.
class KSearchField extends StatelessWidget {
  const KSearchField({
    required this.hint,
    required this.onChanged,
    super.key,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: KSizes.iconMd),
        contentPadding: const EdgeInsets.symmetric(vertical: KSpacing.md),
      ),
    );
  }
}
