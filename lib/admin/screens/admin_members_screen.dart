import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/admin/widgets/admin_page.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/data_refresh.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/error/error_mapper.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/member_enums.dart';
import 'package:kadjane/domain/enums/org_role.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/features/members/presentation/providers/member_providers.dart';

/// Gestion des membres : rôles, statuts et coordonnées.
class AdminMembersScreen extends ConsumerWidget {
  const AdminMembersScreen({super.key});

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    OrganizationMember member, {
    OrgRole? role,
    MemberStatus? status,
  }) async {
    final OrganizationMember? actor = ref
        .read(currentMembershipProvider)
        .valueOrNull;
    if (actor == null) {
      return;
    }
    try {
      await ref
          .read(memberRepositoryProvider)
          .update(
            member: member.copyWith(role: role, status: status),
            actorMemberId: actor.id,
          );
      ref
        ..invalidate(membersProvider)
        ..invalidate(organizationRoleMatrixProvider);
      refreshOrganizationData(ref);
      if (context.mounted) {
        context.showMessage(context.l10n.adminMemberUpdated);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PagedResult<OrganizationMember>> members = ref.watch(
      membersProvider,
    );
    final bool canEdit = ref.watch(canProvider(Permission.memberEdit));

    return AdminPage(
      title: context.l10n.adminNavMembers,
      subtitle: context.l10n.adminOpenMobileHint,
      scrollable: false,
      actions: <Widget>[
        SizedBox(
          width: 280,
          child: KSearchField(
            hint: context.l10n.membersSearchHint,
            onChanged: (String value) =>
                ref.read(memberFilterProvider.notifier).search(value),
          ),
        ),
      ],
      child: KAsyncView<PagedResult<OrganizationMember>>(
        value: members,
        onRetry: () => ref.invalidate(membersProvider),
        isEmpty: (PagedResult<OrganizationMember> data) => data.items.isEmpty,
        emptyBuilder: (BuildContext context) =>
            KEmptyState(message: context.l10n.membersEmpty),
        builder: (PagedResult<OrganizationMember> data) =>
            SingleChildScrollView(
              child: AdminSection(
                title: context.l10n.adminMembersWithRole(data.total),
                padding: EdgeInsets.zero,
                child: AdminTable(
                  columns: <DataColumn>[
                    DataColumn(label: Text(context.l10n.membersTitle)),
                    DataColumn(label: Text(context.l10n.authPhone)),
                    DataColumn(label: Text(context.l10n.membersRole)),
                    DataColumn(label: Text(context.l10n.commonStatus)),
                    DataColumn(label: Text(context.l10n.membersJoinedOn)),
                  ],
                  rows: data.items
                      .map(
                        (OrganizationMember member) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Row(
                                children: <Widget>[
                                  KAvatar(
                                    name: member.fullName,
                                    imageUrl: member.user.avatarUrl,
                                    size: KSizes.avatarSm,
                                  ),
                                  const SizedBox(width: KSpacing.md),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        member.fullName,
                                        style: context.text.titleSmall,
                                      ),
                                      if (member.memberNumber != null)
                                        Text(
                                          member.memberNumber!,
                                          style: context.text.labelSmall,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(member.user.phone),
                                  if (member.user.email != null)
                                    Text(
                                      member.user.email!,
                                      style: context.text.labelSmall,
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              canEdit
                                  ? DropdownButtonHideUnderline(
                                      child: DropdownButton<OrgRole>(
                                        value: member.role,
                                        borderRadius: KRadius.field,
                                        style: context.text.bodyMedium
                                            ?.copyWith(
                                              color: context.colors.textPrimary,
                                            ),
                                        items: OrgRole.values
                                            .where(
                                              (OrgRole r) =>
                                                  r != OrgRole.superAdmin,
                                            )
                                            .map(
                                              (OrgRole role) =>
                                                  DropdownMenuItem<OrgRole>(
                                                    value: role,
                                                    child: Text(
                                                      Labels.role(
                                                        context.l10n,
                                                        role,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                            .toList(growable: false),
                                        onChanged: (OrgRole? role) =>
                                            role == null
                                            ? null
                                            : _apply(
                                                context,
                                                ref,
                                                member,
                                                role: role,
                                              ),
                                      ),
                                    )
                                  : KBadge(
                                      label: Labels.role(
                                        context.l10n,
                                        member.role,
                                      ),
                                      tone: StatusTone(
                                        context.colors.brand,
                                        context.scheme.primaryContainer,
                                      ),
                                      compact: true,
                                    ),
                            ),
                            DataCell(
                              canEdit
                                  ? DropdownButtonHideUnderline(
                                      child: DropdownButton<MemberStatus>(
                                        value: member.status,
                                        borderRadius: KRadius.field,
                                        style: context.text.bodyMedium
                                            ?.copyWith(
                                              color: context.colors.textPrimary,
                                            ),
                                        items: MemberStatus.values
                                            .map(
                                              (MemberStatus status) =>
                                                  DropdownMenuItem<
                                                    MemberStatus
                                                  >(
                                                    value: status,
                                                    child: Text(
                                                      Labels.memberStatus(
                                                        context.l10n,
                                                        status,
                                                      ),
                                                    ),
                                                  ),
                                            )
                                            .toList(growable: false),
                                        onChanged: (MemberStatus? status) =>
                                            status == null
                                            ? null
                                            : _apply(
                                                context,
                                                ref,
                                                member,
                                                status: status,
                                              ),
                                      ),
                                    )
                                  : KBadge(
                                      label: Labels.memberStatus(
                                        context.l10n,
                                        member.status,
                                      ),
                                      tone: StatusTone.member(
                                        context.colors,
                                        member.status,
                                      ),
                                      compact: true,
                                    ),
                            ),
                            DataCell(
                              Text(
                                DateFormatter.date(
                                  member.joinedAt,
                                  context.localeCode,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
      ),
    );
  }
}
