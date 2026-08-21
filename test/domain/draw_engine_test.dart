import 'package:flutter_test/flutter_test.dart';
import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/utils/random_source.dart';
import 'package:kadjane/domain/entities/draw_session.dart';
import 'package:kadjane/domain/services/draw_engine.dart';

void main() {
  const DrawEngine engine = DrawEngine();

  List<DrawParticipant> participants(int count) =>
      List<DrawParticipant>.generate(
        count,
        (int index) => DrawParticipant(
          participantId: 'prt_$index',
          memberId: 'mbr_$index',
          displayName: 'Participant $index',
        ),
      );

  group('DrawEngine.draw', () {
    test('désigne un gagnant appartenant aux candidats', () {
      final List<DrawParticipant> candidates = participants(8);
      final DrawOutcome outcome = engine.draw(
        candidates: candidates,
        random: SeededRandomSource(7),
      );

      expect(candidates, contains(outcome.winner));
      expect(outcome.winnerIndex, inInclusiveRange(0, candidates.length - 1));
      expect(candidates[outcome.winnerIndex], outcome.winner);
    });

    test('est reproductible à graine identique', () {
      final List<DrawParticipant> candidates = participants(12);
      final DrawOutcome first = engine.draw(
        candidates: candidates,
        random: SeededRandomSource(2026),
      );
      final DrawOutcome second = engine.draw(
        candidates: candidates,
        random: SeededRandomSource(2026),
      );

      expect(first.winner.participantId, second.winner.participantId);
      expect(first.seed, 2026);
    });

    test('refuse un tirage sans participant éligible', () {
      expect(
        () => engine.draw(
          candidates: const <DrawParticipant>[],
          random: SeededRandomSource(1),
        ),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('produit une référence de preuve stable pour les mêmes entrées', () {
      final List<DrawParticipant> candidates = participants(5);
      final DateTime at = DateTime.utc(2026, 8, 18, 14, 32);
      final String a = engine.buildProofReference(
        candidates: candidates,
        winnerId: 'prt_2',
        at: at,
      );
      final String b = engine.buildProofReference(
        candidates: candidates,
        winnerId: 'prt_2',
        at: at,
      );
      final String other = engine.buildProofReference(
        candidates: candidates,
        winnerId: 'prt_3',
        at: at,
      );

      expect(a, b);
      expect(a, isNot(other));
      expect(a, startsWith('KDJ-'));
    });
  });

  group('DrawEngine.generateOrder', () {
    test('conserve tous les participants exactement une fois', () {
      final List<DrawParticipant> candidates = participants(10);
      final List<DrawParticipant> ordered = engine.generateOrder(
        participants: candidates,
        random: SeededRandomSource(5),
      );

      expect(ordered.length, candidates.length);
      expect(
        ordered.map((DrawParticipant p) => p.participantId).toSet(),
        candidates.map((DrawParticipant p) => p.participantId).toSet(),
      );
    });

    test('est reproductible à graine identique', () {
      final List<DrawParticipant> candidates = participants(10);
      final List<String> a = engine
          .generateOrder(
            participants: candidates,
            random: SeededRandomSource(99),
          )
          .map((DrawParticipant p) => p.participantId)
          .toList();
      final List<String> b = engine
          .generateOrder(
            participants: candidates,
            random: SeededRandomSource(99),
          )
          .map((DrawParticipant p) => p.participantId)
          .toList();

      expect(a, b);
    });
  });
}
