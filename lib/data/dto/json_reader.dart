import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/core/network/api_client.dart';

/// Lecture défensive des payloads JSON.
///
/// Un champ obligatoire manquant est une rupture de contrat côté backend :
/// on lève une [ServerException] explicite plutôt que de propager un `null`
/// jusque dans l'interface.
class Json {
  const Json._();

  static Never _missing(String key) =>
      throw ServerException('missing_field:$key');

  static String string(JsonMap json, String key) {
    final Object? value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value != null) {
      return '$value';
    }
    _missing(key);
  }

  static String stringOr(JsonMap json, String key, [String fallback = '']) {
    final Object? value = json[key];
    return value == null ? fallback : '$value';
  }

  static String? stringOrNull(JsonMap json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    final String text = '$value';
    return text.isEmpty ? null : text;
  }

  static double amount(JsonMap json, String key, [double fallback = 0]) {
    final Object? value = json[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  /// Nombre décimal **facultatif**, `null` conservé tel quel.
  ///
  /// Un taux de recouvrement absent — cotisation à montant libre — n'est pas
  /// zéro : le remplacer par 0 laisserait croire que personne n'a payé.
  static double? doubleOrNull(JsonMap json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static int integer(JsonMap json, String key, [int fallback = 0]) {
    final Object? value = json[key];
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static bool boolean(JsonMap json, String key, [bool fallback = false]) {
    final Object? value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value == 'true' || value == '1';
    }
    if (value is num) {
      return value != 0;
    }
    return fallback;
  }

  static DateTime date(JsonMap json, String key) {
    final DateTime? parsed = dateOrNull(json, key);
    if (parsed == null) {
      _missing(key);
    }
    return parsed;
  }

  static DateTime? dateOrNull(JsonMap json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.tryParse('$value')?.toLocal();
  }

  /// Objet imbriqué obligatoire.
  static JsonMap object(JsonMap json, String key) {
    final Object? value = json[key];
    if (value is JsonMap) {
      return value;
    }
    _missing(key);
  }

  static JsonMap? objectOrNull(JsonMap json, String key) {
    final Object? value = json[key];
    return value is JsonMap ? value : null;
  }

  /// Tableau d'objets (absent ou nul ⇒ liste vide).
  static List<JsonMap> objects(JsonMap json, String key) {
    final Object? value = json[key];
    if (value is! List<dynamic>) {
      return const <JsonMap>[];
    }
    return value.whereType<JsonMap>().toList(growable: false);
  }

  static List<String> strings(JsonMap json, String key) {
    final Object? value = json[key];
    if (value is! List<dynamic>) {
      return const <String>[];
    }
    return value.map((Object? item) => '$item').toList(growable: false);
  }

  static Map<String, String> stringMap(JsonMap json, String key) {
    final Object? value = json[key];
    if (value is! JsonMap) {
      return const <String, String>{};
    }
    return value.map(
      (String k, dynamic v) => MapEntry<String, String>(k, '$v'),
    );
  }

  static Map<String, Object?> rawMap(JsonMap json, String key) {
    final Object? value = json[key];
    return value is JsonMap ? value : const <String, Object?>{};
  }

  /// Sérialise une date en ISO 8601 UTC, ou `null`.
  static String? iso(DateTime? value) => value?.toUtc().toIso8601String();
}
