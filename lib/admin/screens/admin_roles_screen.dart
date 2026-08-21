import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/entities/role_definition.dart';
import 'package:kadjane/domain/enums/permission.dart';

/// Définitions des rôles de l'organisation active.
final AutoDisposeFutureProvider<List<RoleDefinition>> roleDefinitionsProvider =
    FutureProvider.autoDispose<List<RoleDefinition>>((Ref ref) async {
      final String? organizationId = await ref.watch(
        activeOrganizationIdProvider.future,
      );
      if (organizationId == null) {
        return const <RoleDefinition>[];
      }
      return ref.watch(roleRepositoryProvider).definitions(organizationId);
    });

/// Matrice des permissions : rôles en colonnes, droits en lignes.
class AdminRolesScreen extends ConsumerWidget {
  const AdminRolesScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    RoleDefinition definition,
    Permission permission,
    bool granted,
  ) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }
    try {
      await ref
          .read(roleRepositoryProvider)
          .update(
            definition: definition.toggle(permission, granted: granted),
            actorMemberId: actor.id,
          );
      _refresh(ref);
      if (context.mounted) {
        context.showMessage(context.l10n.adminRoleSaved);
      }
    } on Object catch (error) {
      if (context.mounted) {
        context.showMessage(
          ErrorMapper.message(context.l10n, error),
          isError: true,
        );
      }
    }
  }

  Future<void> _reset(
    BuildContext context,
    WidgetRef ref,
    RoleDefinition definition,
  ) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }
    await ref
        .read(roleRepositoryProvider)
        .resetToDefault(
          organizationId: definition.organizationId,
          role: definition.role,
          actorMemberId: actor.id,
        );
    _refresh(ref);
    if (context.mounted) {
      context.showMessage(context.l10n.adminRoleSaved);
    }
  }

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(roleDefinitionsProvider)
      ..invalidate(organizationRoleMatrixProvider);
    refreshOrganizationData(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RoleDefinition>> definitions = ref.watch(
      roleDefinitionsProvider,
    );
    final bool canEdit = ref.watch(
      canProvider(Permission.organizationManageOfficers),
    );

    return AdminPage(
      title: context.l10n.adminRoleMatrix,
      subtitle: context.l10n.adminRoleMatrixHint,
      child: KAsyncView<List<RoleDefinition>>(
        value: definitions,
        onRetry: () => ref.invalidate(roleDefinitionsProvider),
        isEmpty: (List<RoleDefinition> data) => data.isEmpty,
        builder: (List<RoleDefinition> data) {
          final Map<String, List<Permission>> grouped =
              Labels.permissionsByModule();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: KSpacing.md,
                runSpacing: KSpacing.md,
                children: data
                    .map(
                      (RoleDefinition definition) => _RoleChip(
                        definition: definition,
                        canEdit: canEdit,
                        onReset: () => _reset(context, ref, definition),
                      ),
                    )
                    .toList(growable: false),
              ),
              KSpacing.gapXl,
              AdminSection(
                padding: EdgeInsets.zero,
                child: AdminTable(
                  columns: <DataColumn>[
                    DataColumn(label: Text(context.l10n.commonDetails)),
                    ...data.map(
                      (RoleDefinition d) => DataColumn(
                        label: Text(Labels.role(context.l10n, d.role)),
                      ),
                    ),
                  ],
                  rows: <DataRow>[
                    for (final MapEntry<String, List<Permission>> entry
                        in grouped.entries) ...<DataRow>[
                      DataRow(
                        color: WidgetStatePropertyAll<Color>(
                          context.colors.surfaceMuted.withValues(alpha: 0.5),
                        ),
                        cells: <DataCell>[
                          DataCell(
                            Text(
                              Labels.permissionModule(context.l10n, entry.key),
                              style: context.text.titleSmall,
                            ),
                          ),
                          ...data.map((_) => const DataCell(SizedBox.shrink())),
                        ],
                      ),
                      ...entry.value.map(
                        (Permission permission) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: KSpacing.lg,
                                ),
                                child: Text(
                                  Labels.permissionAction(
                                    context.l10n,
                                    permission,
                                  ),
                                ),
                              ),
                            ),
                            ...data.map(
                              (RoleDefinition definition) => DataCell(
                                Checkbox(
                                  value: definition.has(permission),
                                  onChanged: canEdit
                                      ? (bool? granted) => _toggle(
                                          context,
                                          ref,
                                          definition,
                                          permission,
                                          granted ?? false,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.definition,
    required this.canEdit,
    required this.onReset,
  });

  final RoleDefinition definition;
  final bool canEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: KRadius.card,
        border: Border.all(
          color: definition.isCustomized
              ? context.colors.accent
              : context.colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  Labels.role(context.l10n, definition.role),
                  style: context.text.titleSmall,
                ),
              ),
              KBadge(
                label: definition.isCustomized
                    ? context.l10n.adminRoleCustomized
                    : context.l10n.adminRoleDefault,
                tone: definition.isCustomized
                    ? StatusTone(
                        context.colors.accent,
                        context.colors.accentContainer,
                      )
                    : StatusTone(
                        context.colors.textSecondary,
                        context.colors.surfaceMuted,
                      ),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            context.l10n.adminPermissionsCount(definition.permissions.length),
            style: context.text.bodySmall,
          ),
          if (canEdit && definition.isCustomized) ...<Widget>[
            const SizedBox(height: KSpacing.sm),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt, size: KSizes.iconSm),
              label: Text(context.l10n.adminRoleReset),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
