import 'dart:math';

/// Abstraction de la source d'aléa utilisée par le moteur de tirage.
///
/// Elle permet :
///  * d'utiliser un générateur cryptographique côté client ;
///  * d'injecter une graine déterministe dans les tests ;
///  * de brancher plus tard un tirage calculé côté serveur
///    (voir `RemoteRandomSource` / TODO d'intégration API).
abstract interface class RandomSource {
  /// Retourne un entier dans `[0, max)`.
  int nextInt(int max);

  /// Identifiant lisible de la source, conservé dans la preuve du tirage.
  String get label;
}

/// Source cryptographiquement sûre, utilisée en production côté application.
class SecureRandomSource implements RandomSource {
  SecureRandomSource() : _random = Random.secure();

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  String get label => 'client_secure_random';
}

/// Source déterministe : tests et rejeu d'un tirage à partir de sa graine.
class SeededRandomSource implements RandomSource {
  SeededRandomSource(this.seed) : _random = Random(seed);

  final int seed;
  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  String get label => 'seeded_random:$seed';
}

// TODO(api): implémenter `RemoteRandomSource` qui délègue le tirage au backend
// (endpoint POST /tontines/{id}/draws) afin de garantir l'intégrité du résultat
// même si l'application cliente est compromise.
