import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/date_formatter.dart';
import 'package:kadjane/core/utils/money_formatter.dart';
import 'package:kadjane/design_system/labels.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';
import 'package:kadjane/design_system/widgets/k_avatar.dart';
import 'package:kadjane/design_system/widgets/k_badge.dart';
import 'package:kadjane/design_system/widgets/k_card.dart';
import 'package:kadjane/design_system/widgets/k_stat_tile.dart';
import 'package:kadjane/design_system/widgets/k_states.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization.dart';
import 'package:kadjane/domain/enums/currency.dart';
import 'package:kadjane/features/members/presentation/providers/member_providers.dart';

/// Fiche détaillée d'un membre.
class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({required this.memberId, super.key});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MemberProfile> profile = ref.watch(
      memberProfileProvider(memberId),
    );
    final Organization? organization = ref
        .watch(activeOrganizationProvider)
        .valueOrNull;
    final Currency currency = organization?.currency ?? Currency.xof;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.membersDetails)),
      body: KAsyncView<MemberProfile>(
        value: profile,
        onRetry: () => ref.invalidate(memberProfileProvider(memberId)),
        builder: (MemberProfile data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xxxl,
          ),
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  KAvatar(
                    name: data.member.fullName,
                    imageUrl: data.member.user.avatarUrl,
                    size: KSizes.avatarXl,
                  ),
                  KSpacing.gapLg,
                  Text(
                    data.member.fullName,
                    style: context.text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      KBadge(
                        label: Labels.role(context.l10n, data.member.role),
                        tone: StatusTone(
                          context.colors.brand,
                          context.scheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      KBadge(
                        label: Labels.memberStatus(
                          context.l10n,
                          data.member.status,
                        ),
                        tone: StatusTone.member(
                          context.colors,
                          data.member.status,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.gapXl,
            KStatGrid(
              tiles: <Widget>[
                KStatTile(
                  label: context.l10n.membersTotalPaid,
                  value: MoneyFormatter.compact(data.stats.totalPaid, currency),
                  icon: Icons.arrow_upward,
                  accent: context.colors.success,
                ),
                KStatTile(
                  label: context.l10n.membersTotalReceived,
                  value: MoneyFormatter.compact(
                    data.stats.totalReceived,
                    currency,
                  ),
                  icon: Icons.arrow_downward,
                  accent: context.colors.accent,
                ),
                KStatTile(
                  label: context.l10n.membersTontines,
                  value: '${data.stats.tontinesCount}',
                  icon: Icons.savings_outlined,
                ),
                KStatTile(
                  label: context.l10n.contributionsLate,
                  value: '${data.stats.lateContributions}',
                  icon: Icons.warning_amber_outlined,
                  accent: data.stats.lateContributions > 0
                      ? context.colors.danger
                      : context.colors.success,
                ),
              ],
            ),
            KSpacing.gapLg,
            KCard(
              child: Column(
                children: <Widget>[
                  KDetailRow(
                    label: context.l10n.authPhone,
                    value: data.member.user.phone,
                    icon: Icons.phone_outlined,
                  ),
                  KDetailRow(
                    label: context.l10n.authEmail,
                    value: data.member.user.email ?? context.l10n.commonNone,
                    icon: Icons.mail_outline,
                  ),
                  KDetailRow(
                    label: context.l10n.membersGender,
                    value: Labels.gender(context.l10n, data.member.user.gender),
                    icon: Icons.person_outline,
                  ),
                  KDetailRow(
                    label: context.l10n.membersJoinedOn,
                    value: DateFormatter.date(
                      data.member.joinedAt,
                      context.localeCode,
                    ),
                    icon: Icons.event_outlined,
                  ),
                  if (data.member.memberNumber != null)
                    KDetailRow(
                      label: context.l10n.commonReference,
                      value: data.member.memberNumber!,
                      icon: Icons.badge_outlined,
                    ),
                ],
              ),
            ),
            KSpacing.gapLg,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KSectionHeader(title: context.l10n.contributionsTitle),
                  if (data.contributions.isEmpty)
                    Text(
                      context.l10n.contributionsEmpty,
                      style: context.text.bodyMedium,
                    )
                  else
                    ...data.contributions
                        .take(12)
                        .map(
                          (Contribution contribution) => Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: KSpacing.sm,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    DateFormatter.date(
                                      contribution.paidAt ??
                                          contribution.recordedAt,
                                      context.localeCode,
                                    ),
                                    style: context.text.bodyMedium,
                                  ),
                                ),
                                Text(
                                  MoneyFormatter.format(
                                    contribution.amount,
                                    currency,
                                  ),
                                  style: context.text.titleSmall,
                                ),
                                const SizedBox(width: KSpacing.md),
                                KBadge(
                                  label: Labels.contributionStatus(
                                    context.l10n,
                                    contribution.status,
                                  ),
                                  tone: StatusTone.contribution(
                                    context.colors,
                                    contribution.status,
                                  ),
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
