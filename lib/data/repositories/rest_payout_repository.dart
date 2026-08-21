import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/draw_dto.dart';
import 'package:kadjane/data/dto/json_reader.dart';
import 'package:kadjane/domain/entities/beneficiary.dart';
import 'package:kadjane/domain/entities/payout.dart';
import 'package:kadjane/domain/repositories/payout_repository.dart';

class RestPayoutRepository implements PayoutRepository {
  const RestPayoutRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Beneficiary>> beneficiariesOf(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.beneficiaries(tontineId),
    );
    return response.map(BeneficiaryDto.fromJson).toList(growable: false);
  }

  @override
  Future<Beneficiary?> beneficiaryOfCycle(String cycleId) async {
    final JsonMap response = await _api.get(
      ApiRoutes.cycleBeneficiary(cycleId),
    );
    return response.isEmpty ? null : BeneficiaryDto.fromJson(response);
  }

  @override
  Future<Beneficiary> beneficiaryById(String beneficiaryId) async =>
      BeneficiaryDto.fromJson(
        await _api.get(ApiRoutes.beneficiary(beneficiaryId)),
      );

  @override
  Future<Beneficiary> designateManually({
    required String cycleId,
    required String participantId,
    required String actorMemberId,
  }) async => BeneficiaryDto.fromJson(
    await _api.post(
      ApiRoutes.cycleBeneficiary(cycleId),
      body: <String, dynamic>{
        'participantId': participantId,
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<Payout?> payoutOfCycle(String cycleId) async {
    final JsonMap response = await _api.get(ApiRoutes.cyclePayout(cycleId));
    return response.isEmpty ? null : PayoutDto.fromJson(response);
  }

  @override
  Future<List<Payout>> payoutsOf(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.payouts(tontineId),
    );
    return response.map(PayoutDto.fromJson).toList(growable: false);
  }

  @override
  Future<Payout> record({
    required PayoutDraft draft,
    required String actorMemberId,
  }) async => PayoutDto.fromJson(
    await _api.post(
      ApiRoutes.createPayout,
      body: <String, dynamic>{
        ...PayoutDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<double> totalReceivedBy({
    required String organizationId,
    required String memberId,
  }) async {
    final JsonMap response = await _api.get(
      ApiRoutes.memberPayoutTotal(organizationId, memberId),
    );
    return Json.amount(response, 'total');
  }
}
