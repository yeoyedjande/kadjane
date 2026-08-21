import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/tontine_dto.dart';
import 'package:kadjane/domain/entities/contribution.dart';
import 'package:kadjane/domain/repositories/contribution_repository.dart';

class RestContributionRepository implements ContributionRepository {
  const RestContributionRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ContributionSlot>> slotsForCycle(String cycleId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cycleSlots(cycleId),
    );
    return response.map(ContributionSlotDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<Contribution>> forCycle(String cycleId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cycleContributions(cycleId),
    );
    return response.map(ContributionDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<Contribution>> forTontine(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.tontineContributions(tontineId),
    );
    return response.map(ContributionDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<Contribution>> forMember({
    required String organizationId,
    required String memberId,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.memberContributions(organizationId, memberId),
    );
    return response.map(ContributionDto.fromJson).toList(growable: false);
  }

  @override
  Future<Contribution> record({
    required ContributionDraft draft,
    required String actorMemberId,
  }) async => ContributionDto.fromJson(
    await _api.post(
      ApiRoutes.tontineContributions(draft.tontineId),
      body: <String, dynamic>{
        ...ContributionDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<Contribution> confirm({
    required String contributionId,
    required String actorMemberId,
  }) async => ContributionDto.fromJson(
    await _api.post(
      ApiRoutes.confirmContribution(contributionId),
      body: <String, dynamic>{'actorMemberId': actorMemberId},
    ),
  );

  @override
  Future<Contribution> cancel({
    required String contributionId,
    required String reason,
    required String actorMemberId,
  }) async => ContributionDto.fromJson(
    await _api.post(
      ApiRoutes.cancelContribution(contributionId),
      body: <String, dynamic>{'reason': reason, 'actorMemberId': actorMemberId},
    ),
  );
}
