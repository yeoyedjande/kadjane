import 'package:kadjane/core/network/api_client.dart';
import 'package:kadjane/data/dto/draw_dto.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/repositories/draw_repository.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Tirage calculé et scellé par le backend.
///
/// C'est l'objectif final en matière d'intégrité : l'application ne fait
/// qu'afficher un résultat qu'elle ne peut pas influencer.
class RestDrawRepository implements DrawRepository {
  const RestDrawRepository(this._api);

  final ApiClient _api;

  @override
  Future<DrawEligibility> eligibility({
    required String tontineId,
    required String cycleId,
  }) async => DrawEligibilityDto.fromJson(
    await _api.get(ApiRoutes.drawEligibility(tontineId, cycleId)),
  );

  @override
  Future<DrawSession> run(RunDrawCommand command) async =>
      DrawSessionDto.fromJson(
        await _api.post(
          ApiRoutes.draws(command.tontineId),
          body: <String, dynamic>{
            'cycleId': command.cycleId,
            'actorMemberId': command.actorMemberId,
            'override': command.override,
            'overrideReason': command.overrideReason,
            'seed': command.seed,
          },
        ),
      );

  @override
  Future<DrawSession> generateFullOrder({
    required String tontineId,
    required String actorMemberId,
    int? seed,
  }) async => DrawSessionDto.fromJson(
    await _api.post(
      ApiRoutes.orderDraw(tontineId),
      body: <String, dynamic>{'actorMemberId': actorMemberId, 'seed': seed},
    ),
  );

  @override
  Future<List<DrawSession>> historyOf(String tontineId) async {
    final List<JsonMap> response = await _api.getList(
      ApiRoutes.draws(tontineId),
    );
    return response.map(DrawSessionDto.fromJson).toList(growable: false);
  }

  @override
  Future<DrawSession> byId(String drawId) async =>
      DrawSessionDto.fromJson(await _api.get(ApiRoutes.draw(drawId)));

  @override
  Future<DrawSession?> forCycle(String cycleId) async {
    final JsonMap response = await _api.get(ApiRoutes.cycleDraw(cycleId));
    return response.isEmpty ? null : DrawSessionDto.fromJson(response);
  }

  @override
  Future<DrawSession> cancel({
    required String drawId,
    required String reason,
    required String actorMemberId,
  }) async => DrawSessionDto.fromJson(
    await _api.post(
      ApiRoutes.cancelDraw(drawId),
      body: <String, dynamic>{'reason': reason, 'actorMemberId': actorMemberId},
    ),
  );

  @override
  Future<DrawSession> invalidate({
    required String drawId,
    required String reason,
    required String actorMemberId,
  }) async => DrawSessionDto.fromJson(
    await _api.post(
      ApiRoutes.invalidateDraw(drawId),
      body: <String, dynamic>{'reason': reason, 'actorMemberId': actorMemberId},
    ),
  );
}
