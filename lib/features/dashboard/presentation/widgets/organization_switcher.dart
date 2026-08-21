import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/domain/entities/organization.dart';

/// Sélecteur d'organisation active (plateforme multi-organisation).
class OrganizationSwitcher extends ConsumerWidget {
  const OrganizationSwitcher({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final List<Organization> organizations =
        ref.read(userOrganizationsProvider).valueOrNull ??
        const <Organization>[];
    final String? activeId = ref.read(activeOrganizationIdProvider).valueOrNull;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.sm,
                KSpacing.xl,
                KSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    sheetContext.l10n.orgSwitch,
                    style: sheetContext.text.titleMedium,
                  ),
                ],
              ),
            ),
            ...organizations.map(
              (Organization organization) => ListTile(
                leading: KAvatar(
                  name: organization.name,
                  imageUrl: organization.logoUrl,
                ),
                title: Text(organization.name),
                subtitle: Text(
                  organization.description ?? organization.country,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: organization.id == activeId
                    ? Icon(
                        Icons.check_circle,
                        color: sheetContext.colors.success,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(activeOrganizationIdProvider.notifier)
                      .select(organization.id);
                },
              ),
            ),
            const SizedBox(height: KSpacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    if (organization == null) {
      return const SizedBox.shrink();
    }
    return InkWell(
      borderRadius: KRadius.badge,
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm,
          vertical: KSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            KAvatar(
              name: organization.name,
              imageUrl: organization.logoUrl,
              size: KSizes.avatarSm,
            ),
            const SizedBox(width: KSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                organization.name,
                style: context.text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: KSizes.iconSm),
          ],
        ),
      ),
    );
  }
}
