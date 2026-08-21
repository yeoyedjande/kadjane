import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/admin/router/admin_routes.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/design_system/widgets/k_logo.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/user.dart';

/// Entrée de navigation de la console.
class AdminNavItem {
  const AdminNavItem({
    required this.route,
    required this.icon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final String Function(BuildContext context) label;
}

/// Coquille de la console : navigation latérale persistante et en-tête.
///
/// Sur écran étroit, la navigation bascule dans un tiroir : la console reste
/// utilisable depuis une tablette.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  static const double _sidebarWidth = 268;
  static const double _wideBreakpoint = 1040;

  static final List<AdminNavItem> items = <AdminNavItem>[
    AdminNavItem(
      route: AdminRoutes.overview,
      icon: Icons.space_dashboard_outlined,
      label: (BuildContext c) => c.l10n.adminNavOverview,
    ),
    AdminNavItem(
      route: AdminRoutes.members,
      icon: Icons.groups_2_outlined,
      label: (BuildContext c) => c.l10n.adminNavMembers,
    ),
    AdminNavItem(
      route: AdminRoutes.roles,
      icon: Icons.admin_panel_settings_outlined,
      label: (BuildContext c) => c.l10n.adminNavRoles,
    ),
    AdminNavItem(
      route: AdminRoutes.reminders,
      icon: Icons.campaign_outlined,
      label: (BuildContext c) => c.l10n.adminNavReminders,
    ),
    AdminNavItem(
      route: AdminRoutes.tontines,
      icon: Icons.savings_outlined,
      label: (BuildContext c) => c.l10n.adminNavTontines,
    ),
    AdminNavItem(
      route: AdminRoutes.audit,
      icon: Icons.fact_check_outlined,
      label: (BuildContext c) => c.l10n.adminNavAudit,
    ),
    AdminNavItem(
      route: AdminRoutes.settings,
      icon: Icons.settings_outlined,
      label: (BuildContext c) => c.l10n.adminNavSettings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final String location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: context.colors.surfaceMuted,
      drawer: isWide
          ? null
          : Drawer(child: _Sidebar(location: location, inDrawer: true)),
      appBar: isWide
          ? null
          : AppBar(
              title: Text(context.l10n.adminConsole),
              backgroundColor: context.scheme.surface,
            ),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (isWide)
              SizedBox(
                width: _sidebarWidth,
                child: _Sidebar(location: location, inDrawer: false),
              ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(isWide ? KSpacing.lg : 0),
                decoration: BoxDecoration(
                  color: context.scheme.surface,
                  borderRadius: isWide ? KRadius.card : BorderRadius.zero,
                  border: isWide
                      ? Border.all(color: context.colors.divider)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.inDrawer});

  final String location;
  final bool inDrawer;

  bool _isSelected(String route) {
    if (route == AdminRoutes.overview) {
      return location == route;
    }
    return location.startsWith(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(currentUserProvider);
    final OrganizationMember? membership = ref
        .watch(currentMembershipProvider)
        .valueOrNull;
    final List<Organization> organizations =
        ref.watch(userOrganizationsProvider).valueOrNull ??
        const <Organization>[];
    final String? activeId = ref
        .watch(activeOrganizationIdProvider)
        .valueOrNull;
    final AppSettings settings = ref.watch(appSettingsProvider);

    return Container(
      color: context.scheme.surface,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Row(
              children: <Widget>[
                const KLogo(size: 38),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.appName,
                        style: context.text.titleMedium,
                      ),
                      Text(
                        context.l10n.adminConsole,
                        style: context.text.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sélecteur d'organisation.
          if (organizations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: KRadius.field,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: activeId,
                    borderRadius: KRadius.field,
                    style: context.text.titleSmall,
                    items: organizations
                        .map(
                          (Organization o) => DropdownMenuItem<String>(
                            value: o.id,
                            child: Text(
                              o.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? id) {
                      if (id != null) {
                        ref
                            .read(activeOrganizationIdProvider.notifier)
                            .select(id);
                      }
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: KSpacing.lg),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              children: AdminShell.items
                  .map(
                    (AdminNavItem item) => _NavTile(
                      item: item,
                      selected: _isSelected(item.route),
                      onTap: () {
                        if (inDrawer) {
                          Navigator.of(context).pop();
                        }
                        context.go(item.route);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ),

          const Divider(height: KSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Row(
              children: <Widget>[
                KAvatar(
                  name: user?.fullName ?? '?',
                  imageUrl: user?.avatarUrl,
                  size: KSizes.avatarSm,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user?.fullName ?? '',
                        style: context.text.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (membership != null)
                        Text(
                          Labels.role(context.l10n, membership.role),
                          style: context.text.labelSmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: settings.themeMode == ThemeMode.dark
                      ? context.l10n.profileThemeLight
                      : context.l10n.profileThemeDark,
                  icon: Icon(
                    settings.themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: KSizes.iconSm,
                  ),
                  onPressed: () => ref
                      .read(appSettingsProvider.notifier)
                      .setThemeMode(
                        settings.themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark,
                      ),
                ),
                IconButton(
                  tooltip: context.l10n.authLogout,
                  icon: const Icon(Icons.logout, size: KSizes.iconSm),
                  onPressed: () async {
                    final bool confirmed = await KConfirmDialog.show(
                      context,
                      title: context.l10n.authLogout,
                      message: context.l10n.authLogoutConfirm,
                      confirmLabel: context.l10n.authLogout,
                      isDestructive: true,
                      icon: Icons.logout,
                    );
                    if (confirmed) {
                      await ref.read(authControllerProvider.notifier).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.xs),
      child: Material(
        color: selected ? context.scheme.primaryContainer : Colors.transparent,
        borderRadius: KRadius.field,
        child: InkWell(
          onTap: onTap,
          borderRadius: KRadius.field,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  item.icon,
                  size: KSizes.iconMd,
                  color: selected
                      ? context.scheme.onPrimaryContainer
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Text(
                    item.label(context),
                    style: context.text.titleSmall?.copyWith(
                      color: selected
                          ? context.scheme.onPrimaryContainer
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
