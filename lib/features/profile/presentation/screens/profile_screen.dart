import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/app_settings_controller.dart';
import 'package:kadjane/app/state/auth_controller.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/config/app_config.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_dialogs.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Profil de l'utilisateur, préférences et accès aux réglages.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(currentUserProvider);
    final OrganizationMember? membership = ref
        .watch(currentMembershipProvider)
        .valueOrNull;
    final List<Organization> organizations =
        ref.watch(userOrganizationsProvider).valueOrNull ??
        const <Organization>[];
    final AppSettings settings = ref.watch(appSettingsProvider);
    final bool canEditOrganization = ref.watch(
      canProvider(Permission.organizationEdit),
    );

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.lg,
          KSpacing.xxxl,
        ),
        children: <Widget>[
          KCard(
            child: Row(
              children: <Widget>[
                KAvatar(
                  name: user.fullName,
                  imageUrl: user.avatarUrl,
                  size: KSizes.avatarLg,
                ),
                const SizedBox(width: KSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(user.fullName, style: context.text.titleMedium),
                      const SizedBox(height: KSpacing.xxs),
                      Text(user.phone, style: context.text.bodySmall),
                      if (user.email != null)
                        Text(user.email!, style: context.text.bodySmall),
                      if (membership != null) ...<Widget>[
                        const SizedBox(height: KSpacing.sm),
                        KBadge(
                          label: Labels.role(context.l10n, membership.role),
                          tone: StatusTone(
                            context.colors.brand,
                            context.scheme.primaryContainer,
                          ),
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          KSpacing.gapLg,

          KSectionHeader(title: context.l10n.profileMyOrganizations),
          ...organizations.map(
            (Organization organization) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: KAvatar(
                name: organization.name,
                imageUrl: organization.logoUrl,
                size: KSizes.avatarSm,
              ),
              title: Text(organization.name, style: context.text.titleSmall),
              subtitle: Text(
                organization.country,
                style: context.text.bodySmall,
              ),
              trailing:
                  organization.id ==
                      ref.watch(activeOrganizationIdProvider).valueOrNull
                  ? Icon(Icons.check_circle, color: context.colors.success)
                  : null,
              onTap: () => ref
                  .read(activeOrganizationIdProvider.notifier)
                  .select(organization.id),
            ),
          ),
          if (canEditOrganization) ...<Widget>[
            KSpacing.gapSm,
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.l10n.orgSettingsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.organizationSettings),
            ),
          ],
          const Divider(height: KSpacing.xxl),

          KSectionHeader(title: context.l10n.profilePreferences),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(context.l10n.profileTheme),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<ThemeMode>>[
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.system,
                  child: Text(context.l10n.profileThemeSystem),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.light,
                  child: Text(context.l10n.profileThemeLight),
                ),
                DropdownMenuItem<ThemeMode>(
                  value: ThemeMode.dark,
                  child: Text(context.l10n.profileThemeDark),
                ),
              ],
              onChanged: (ThemeMode? mode) {
                if (mode != null) {
                  ref.read(appSettingsProvider.notifier).setThemeMode(mode);
                }
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_outlined),
            title: Text(context.l10n.profileLanguage),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'fr',
                  child: Text(context.l10n.profileFrench),
                ),
                DropdownMenuItem<String>(
                  value: 'en',
                  child: Text(context.l10n.profileEnglish),
                ),
              ],
              onChanged: (String? code) {
                if (code != null) {
                  ref
                      .read(appSettingsProvider.notifier)
                      .setLocale(Locale(code));
                }
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(context.l10n.authChangePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.changePassword),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(context.l10n.profileNotifications),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_chart_outlined),
            title: Text(context.l10n.reportsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.reports),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(context.l10n.treasuryTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.treasury),
          ),
          const Divider(height: KSpacing.xxl),

          KSectionHeader(title: context.l10n.profileSecurity),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout, color: context.colors.danger),
            title: Text(
              context.l10n.authLogout,
              style: TextStyle(color: context.colors.danger),
            ),
            onTap: () async {
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
          KSpacing.gapLg,
          Center(
            child: Text(
              '${context.l10n.profileVersion} 1.0.0 · '
              '${AppConfig.current.environment.code}',
              style: context.text.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
