import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadjane/app/router/app_routes.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/design_system/widgets/k_text_field.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/enums/permission.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';
import 'package:kadjane/features/members/presentation/providers/member_providers.dart';

/// Liste des membres de l'organisation active.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PagedResult<OrganizationMember>> members = ref.watch(
      membersProvider,
    );
    final bool canCreate = ref.watch(canProvider(Permission.memberCreate));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.membersTitle)),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.memberCreate),
              icon: const Icon(Icons.person_add_alt),
              label: Text(context.l10n.membersAdd),
            )
          : null,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.sm,
              KSpacing.lg,
              KSpacing.md,
            ),
            child: KSearchField(
              hint: context.l10n.membersSearchHint,
              onChanged: (String value) =>
                  ref.read(memberFilterProvider.notifier).search(value),
            ),
          ),
          Expanded(
            child: KAsyncView<PagedResult<OrganizationMember>>(
              value: members,
              onRetry: () => ref.invalidate(membersProvider),
              isEmpty: (PagedResult<OrganizationMember> data) =>
                  data.items.isEmpty,
              emptyBuilder: (BuildContext context) => KEmptyState(
                icon: Icons.groups_2_outlined,
                message: context.l10n.membersEmpty,
                actionLabel: canCreate ? context.l10n.membersAdd : null,
                onAction: canCreate
                    ? () => context.push(AppRoutes.memberCreate)
                    : null,
              ),
              builder: (PagedResult<OrganizationMember> data) =>
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (ScrollEndNotification notification) {
                      final ScrollMetrics metrics = notification.metrics;
                      if (data.hasMore &&
                          metrics.pixels >= metrics.maxScrollExtent - 80) {
                        ref.read(memberFilterProvider.notifier).nextPage();
                      }
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        KSpacing.lg,
                        0,
                        KSpacing.lg,
                        KSpacing.giant,
                      ),
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= data.items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(KSpacing.lg),
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return MemberTile(member: data.items[index]);
                      },
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne « membre » réutilisée dans plusieurs écrans.
class MemberTile extends StatelessWidget {
  const MemberTile({
    required this.member,
    super.key,
    this.trailing,
    this.onTap,
  });

  final OrganizationMember member;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap ?? () => context.push(AppRoutes.memberDetail(member.id)),
      leading: KAvatar(name: member.fullName, imageUrl: member.user.avatarUrl),
      title: Text(member.fullName, style: context.text.titleSmall),
      subtitle: Text(member.user.phone, style: context.text.bodySmall),
      trailing:
          trailing ??
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              KBadge(
                label: Labels.role(context.l10n, member.role),
                tone: StatusTone(
                  context.colors.brand,
                  context.scheme.primaryContainer,
                ),
                compact: true,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                Labels.memberStatus(context.l10n, member.status),
                style: context.text.labelSmall?.copyWith(
                  color: StatusTone.member(
                    context.colors,
                    member.status,
                  ).foreground,
                ),
              ),
            ],
          ),
    );
  }
}
