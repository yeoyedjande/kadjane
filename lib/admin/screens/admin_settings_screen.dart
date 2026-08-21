import 'package:flutter/material.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/features/organization/presentation/screens/organization_settings_screen.dart';

/// Paramètres de l'organisation dans la console.
///
/// L'écran de réglages est partagé avec l'application mobile : une seule
/// implémentation, deux points d'entrée.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: context.l10n.orgSettingsTitle,
      subtitle: context.l10n.orgRules,
      scrollable: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KSizes.contentMaxWidth),
          child: const OrganizationSettingsScreen(embedded: true),
        ),
      ),
    );
  }
}
