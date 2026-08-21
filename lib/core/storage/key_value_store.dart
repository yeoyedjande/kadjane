import 'package:shared_preferences/shared_preferences.dart';

/// Stockage clé/valeur non sensible (thème, langue, onboarding vu...).
abstract interface class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<bool?> getBool(String key);

  Future<void> setBool(String key, bool value);

  Future<void> remove(String key);
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesStore> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStore(prefs);
  }

  @override
  Future<String?> getString(String key) async => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool?> getBool(String key) async => _preferences.getBool(key);

  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Implémentation mémoire (tests, mode dégradé).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Clés de préférences utilisées par l'application.
class StorageKeys {
  const StorageKeys._();

  static const String themeMode = 'kadjane.theme_mode';
  static const String locale = 'kadjane.locale';
  static const String onboardingSeen = 'kadjane.onboarding_seen';
  static const String activeOrganization = 'kadjane.active_organization';
  static const String authTokens = 'kadjane.auth_tokens';
  static const String currentUserId = 'kadjane.current_user_id';
}
