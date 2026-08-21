/// Validation de formulaires, indépendante de l'UI.
///
/// Les fonctions retournent `null` si la valeur est valide, sinon une clé de
/// message que l'écran traduit via `AppLocalizations`.
class Validators {
  const Validators._();

  static const int minPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s-]{8,20}$');

  static bool isBlank(String? value) => value == null || value.trim().isEmpty;

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  static bool isValidPhone(String value) =>
      _phonePattern.hasMatch(value.trim());

  static bool isValidPassword(String value) =>
      value.length >= minPasswordLength;

  static bool isPositiveAmount(String value) {
    final double? parsed = parseAmount(value);
    return parsed != null && parsed > 0;
  }

  /// Accepte `50 000`, `50000`, `50 000,50`.
  static double? parseAmount(String value) {
    final String normalized = value
        .replaceAll(RegExp(r'[\s  ]'), '')
        .replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}
