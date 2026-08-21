import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/services/tontine_rules_service.dart';

/// Commande de lancement d'un tirage.
class RunDrawCommand {
  const RunDrawCommand({
    required this.tontineId,
    required this.cycleId,
    required this.actorMemberId,
    this.override = false,
    this.overrideReason,
    this.seed,
  });

  final String tontineId;
  final String cycleId;
  final String actorMemberId;

  /// Forçage malgré des cotisations manquantes (toujours audité).
  final bool override;
  final String? overrideReason;

  /// Graine facultative : rejeu déterministe (tests, vérification).
  final int? seed;
}

abstract interface class DrawRepository {
  /// Évalue si le tirage du cycle est autorisé et pourquoi.
  Future<DrawEligibility> eligibility({
    required String tontineId,
    required String cycleId,
  });

  /// Exécute le tirage : le bénéficiaire est déterminé ici, pas par l'animation.
  ///
  /// TODO(api): déléguer ce calcul au backend (POST /tontines/{id}/draws) pour
  /// une intégrité vérifiable côté serveur.
  Future<DrawSession> run(RunDrawCommand command);

  /// Mode B : tirage unique définissant l'ordre complet de passage.
  Future<DrawSession> generateFullOrder({
    required String tontineId,
    required String actorMemberId,
    int? seed,
  });

  Future<List<DrawSession>> historyOf(String tontineId);

  Future<DrawSession> byId(String drawId);

  Future<DrawSession?> forCycle(String cycleId);

  /// Annule un tirage programmé (aucune suppression définitive).
  Future<DrawSession> cancel({
    required String drawId,
    required String reason,
    required String actorMemberId,
  });

  /// Invalide un tirage déjà validé : le bénéficiaire redevient éligible et
  /// l'opération est tracée dans l'audit.
  Future<DrawSession> invalidate({
    required String drawId,
    required String reason,
    required String actorMemberId,
  });
}
