import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Mise en page standard d'une page de la console : titre, sous-titre,
/// actions, puis contenu défilant.
class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.actions = const <Widget>[],
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final Widget header = Container(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.xxl,
        KSpacing.xl,
        KSpacing.xxl,
        KSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: KSpacing.xxs),
                  Text(subtitle!, style: context.text.bodyMedium),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) Wrap(spacing: KSpacing.md, children: actions),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        header,
        Expanded(
          child: scrollable
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(KSpacing.xxl),
                  child: child,
                )
              : Padding(
                  padding: const EdgeInsets.all(KSpacing.xxl),
                  child: child,
                ),
        ),
      ],
    );
  }
}

/// Bloc de contenu encadré, utilisé pour les tableaux et les formulaires.
class AdminSection extends StatelessWidget {
  const AdminSection({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(KSpacing.lg),
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: KRadius.card,
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title!, style: context.text.titleMedium),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: KSpacing.xxs),
                          Text(subtitle!, style: context.text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Tableau de données horizontalement défilant, aux couleurs du thème.
class AdminTable extends StatelessWidget {
  const AdminTable({
    required this.columns,
    required this.rows,
    super.key,
    this.emptyLabel,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xxl),
        child: Center(
          child: Text(
            emptyLabel ?? context.l10n.commonNoResults,
            style: context.text.bodyMedium,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columns: columns,
                rows: rows,
                headingRowColor: WidgetStatePropertyAll<Color>(
                  context.colors.surfaceMuted,
                ),
                headingTextStyle: context.text.labelMedium,
                dataTextStyle: context.text.bodyMedium?.copyWith(
                  color: context.colors.textPrimary,
                ),
                dividerThickness: 1,
                columnSpacing: KSpacing.xxl,
                horizontalMargin: KSpacing.lg,
              ),
            ),
          ),
    );
  }
}
