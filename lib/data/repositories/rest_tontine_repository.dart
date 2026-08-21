import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/tontine_dto.dart';
import 'package:kadjane/domain/entities/tontine.dart';
import 'package:kadjane/domain/entities/tontine_cycle.dart';
import 'package:kadjane/domain/entities/tontine_participant.dart';
import 'package:kadjane/domain/enums/tontine_enums.dart';
import 'package:kadjane/domain/repositories/tontine_repository.dart';

class RestTontineRepository implements TontineRepository {
  const RestTontineRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<TontineSummary>> list({
    required String organizationId,
    TontineStatus? status,
    String? memberId,
  }) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.tontines(organizationId),
      query: <String, dynamic>{
        if (status != null) 'status': status.code,
        'memberId': ?memberId,
      },
    );
    return response.map(TontineSummaryDto.fromJson).toList(growable: false);
  }

  @override
  Future<TontineSummary> summaryOf(String tontineId) async =>
      TontineSummaryDto.fromJson(
        await _api.get(ApiRoutes.tontineSummary(tontineId)),
      );

  @override
  Future<Tontine> byId(String tontineId) async =>
      TontineDto.fromJson(await _api.get(ApiRoutes.tontine(tontineId)));

  @override
  Future<Tontine> create({
    required String organizationId,
    required TontineDraft draft,
    required String actorMemberId,
  }) async => TontineDto.fromJson(
    await _api.post(
      ApiRoutes.tontines(organizationId),
      body: <String, dynamic>{
        ...TontineDto.draftToJson(draft),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<Tontine> update({
    required Tontine tontine,
    required String actorMemberId,
  }) async => TontineDto.fromJson(
    await _api.put(
      ApiRoutes.tontine(tontine.id),
      body: <String, dynamic>{
        ...TontineDto.toJson(tontine),
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<Tontine> changeStatus({
    required String tontineId,
    required TontineStatus status,
    required String actorMemberId,
  }) async => TontineDto.fromJson(
    await _api.patch(
      ApiRoutes.tontineStatus(tontineId),
      body: <String, dynamic>{
        'status': status.code,
        'actorMemberId': actorMemberId,
      },
    ),
  );

  @override
  Future<List<TontineParticipant>> participants(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.participants(tontineId),
    );
    return response.map(TontineParticipantDto.fromJson).toList(growable: false);
  }

  @override
  Future<List<TontineCycle>> cycles(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.cycles(tontineId),
    );
    return response.map(TontineCycleDto.fromJson).toList(growable: false);
  }

  @override
  Future<TontineCycle> cycleById(String cycleId) async =>
      TontineCycleDto.fromJson(await _api.get(ApiRoutes.cycle(cycleId)));

  @override
  Future<TontineCycle?> currentCycle(String tontineId) async {
    final JsonMap response = await _api.get(ApiRoutes.currentCycle(tontineId));
    // Un corps vide signifie « aucun cycle en cours ».
    return response.isEmpty ? null : TontineCycleDto.fromJson(response);
  }

  @override
  Future<void> setManualOrder({
    required String tontineId,
    required List<String> participantIdsInOrder,
    required String actorMemberId,
  }) async {
    await _api.put(
      ApiRoutes.participantsOrder(tontineId),
      body: <String, dynamic>{
        'participantIds': participantIdsInOrder,
        'actorMemberId': actorMemberId,
      },
    );
  }
}
