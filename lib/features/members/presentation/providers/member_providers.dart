import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kadjane/app/di/providers.dart';
import 'package:kadjane/app/state/session_controller.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/entities/organization_member.dart';
import 'package:kadjane/domain/repositories/member_repository.dart';

/// Filtre courant de la liste des membres.
class MemberFilter {
  const MemberFilter({this.query = '', this.page = 0});

  final String query;
  final int page;

  MemberFilter copyWith({String? query, int? page}) =>
      MemberFilter(query: query ?? this.query, page: page ?? this.page);
}

class MemberFilterController extends Notifier<MemberFilter> {
  @override
  MemberFilter build() => const MemberFilter();

  void search(String query) => state = MemberFilter(query: query);

  void nextPage() => state = state.copyWith(page: state.page + 1);
}

final NotifierProvider<MemberFilterController, MemberFilter>
memberFilterProvider = NotifierProvider<MemberFilterController, MemberFilter>(
  MemberFilterController.new,
);

/// Membres de l'organisation active (avec recherche et pagination).
final AutoDisposeFutureProvider<PagedResult<OrganizationMember>>
membersProvider = FutureProvider.autoDispose<PagedResult<OrganizationMember>>((
  Ref ref,
) async {
  final String? organizationId = await ref.watch(
    activeOrganizationIdProvider.future,
  );
  if (organizationId == null) {
    return const PagedResult<OrganizationMember>(
      items: <OrganizationMember>[],
      page: 0,
      hasMore: false,
      total: 0,
    );
  }
  final MemberFilter filter = ref.watch(memberFilterProvider);
  return ref
      .watch(memberRepositoryProvider)
      .list(
        organizationId: organizationId,
        query: filter.query,
        pageSize: 20 * (filter.page + 1),
      );
});

/// Fiche complète d'un membre : identité, statistiques et cotisations.
class MemberProfile {
  const MemberProfile({
    required this.member,
    required this.stats,
    required this.contributions,
  });

  final OrganizationMember member;
  final MemberStats stats;
  final List<Contribution> contributions;
}

final AutoDisposeFutureProviderFamily<MemberProfile, String>
memberProfileProvider = FutureProvider.autoDispose
    .family<MemberProfile, String>((Ref ref, String memberId) async {
      final MemberRepository repository = ref.watch(memberRepositoryProvider);
      final OrganizationMember member = await repository.byId(memberId);
      final MemberStats stats = await repository.statsOf(memberId);
      final List<Contribution> contributions = await ref
          .watch(contributionRepositoryProvider)
          .forMember(organizationId: member.organizationId, memberId: memberId);
      return MemberProfile(
        member: member,
        stats: stats,
        contributions: contributions,
      );
    });
