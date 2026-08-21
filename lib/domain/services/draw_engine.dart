import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/random_source.dart';
import 'package:kadjane/domain/entities/draw_session.dart';

/// Résultat brut d'un tirage.
class DrawOutcome {
  const DrawOutcome({
    required this.winner,
    required this.winnerIndex,
    required this.proofReference,
    required this.randomSourceLabel,
    required this.candidates,
    this.seed,
  });

  final DrawParticipant winner;

  /// Index du gagnant dans la liste des candidats : l'animation de la roue
  /// s'aligne sur cette valeur, elle ne la détermine jamais.
  final int winnerIndex;
  final String proofReference;
  final String randomSourceLabel;
  final List<DrawParticipant> candidates;
  final int? seed;
}

/// Moteur de tirage au sort.
///
/// IMPORTANT : le résultat est déterminé **ici**, jamais par l'animation. La
/// roue affiche simplement le gagnant déjà calculé. Le jour où le backend
/// calculera le tirage, il suffira d'injecter une [RandomSource] distante ou
/// de remplacer l'appel par la réponse serveur.
class DrawEngine {
  const DrawEngine();

  /// Tire un bénéficiaire parmi les [candidates] éligibles.
  DrawOutcome draw({
    required List<DrawParticipant> candidates,
    required RandomSource random,
    DateTime? at,
  }) {
    if (candidates.isEmpty) {
      throw const BusinessRuleException(
        'no_eligible_participant',
        code: 'draw.no_eligible',
      );
    }
    final int index = random.nextInt(candidates.length);
    final DrawParticipant winner = candidates[index];
    return DrawOutcome(
      winner: winner,
      winnerIndex: index,
      candidates: List<DrawParticipant>.unmodifiable(candidates),
      randomSourceLabel: random.label,
      seed: random is SeededRandomSource ? random.seed : null,
      proofReference: buildProofReference(
        candidates: candidates,
        winnerId: winner.participantId,
        at: at ?? DateTime.now(),
      ),
    );
  }

  /// Mode B : un tirage unique fixe l'ordre de passage complet.
  ///
  /// Mélange de Fisher-Yates alimenté par la même source d'aléa.
  List<DrawParticipant> generateOrder({
    required List<DrawParticipant> participants,
    required RandomSource random,
  }) {
    if (participants.isEmpty) {
      throw const BusinessRuleException(
        'no_participant',
        code: 'draw.no_participant',
      );
    }
    final List<DrawParticipant> shuffled = List<DrawParticipant>.of(
      participants,
    );
    for (int i = shuffled.length - 1; i > 0; i--) {
      final int j = random.nextInt(i + 1);
      final DrawParticipant tmp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = tmp;
    }
    return List<DrawParticipant>.unmodifiable(shuffled);
  }

  /// Référence de preuve reproductible à partir des entrées du tirage.
  ///
  /// Elle permet de vérifier a posteriori qu'un résultat correspond bien à la
  /// liste de participants et à l'horodatage enregistrés.
  String buildProofReference({
    required List<DrawParticipant> candidates,
    required String winnerId,
    required DateTime at,
  }) {
    final String payload =
        '${candidates.map((DrawParticipant c) => c.participantId).join('|')}'
        '>$winnerId@${at.toUtc().toIso8601String()}';
    return 'KDJ-${_fnv1a(payload)}';
  }

  /// Hachage FNV-1a 32 bits, rendu en base 16 majuscule.
  static String _fnv1a(String input) {
    int hash = 0x811c9dc5;
    for (final int codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).toUpperCase().padLeft(8, '0');
  }
}
