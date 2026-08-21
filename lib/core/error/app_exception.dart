/// Hiérarchie d'exceptions métier de Kadjane.
///
/// Les repositories lèvent uniquement des [AppException] : la couche
/// présentation n'a jamais à connaître le transport (HTTP, mock, cache...).
library;

sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  /// Message technique (jamais affiché tel quel : voir `ErrorMapper`).
  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Problème réseau (timeout, DNS, socket...).
class NetworkException extends AppException {
  const NetworkException([super.message = 'network_error', Object? cause])
    : super(code: 'network', cause: cause);
}

/// L'appareil n'a pas de connexion.
class OfflineException extends AppException {
  const OfflineException([super.message = 'offline']) : super(code: 'offline');
}

/// Erreur renvoyée par le serveur (5xx).
class ServerException extends AppException {
  const ServerException([super.message = 'server_error', this.statusCode])
    : super(code: 'server');

  final int? statusCode;
}

/// Identifiants invalides / session expirée.
class AuthException extends AppException {
  const AuthException(super.message, {String? code})
    : super(code: code ?? 'auth');
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException()
    : super('session_expired', code: 'session_expired');
}

/// L'utilisateur n'a pas la permission requise.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([super.message = 'permission_denied'])
    : super(code: 'permission_denied');
}

/// Ressource introuvable.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'not_found'])
    : super(code: 'not_found');
}

/// Violation d'une règle métier (ex : tirage déjà effectué).
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, {String? code, this.details})
    : super(code: code ?? 'business_rule');

  final Map<String, Object?>? details;
}

/// Données saisies invalides.
class ValidationException extends AppException {
  const ValidationException(super.message, {this.fieldErrors})
    : super(code: 'validation');

  final Map<String, String>? fieldErrors;
}

/// Erreur inattendue.
class UnexpectedException extends AppException {
  const UnexpectedException([super.message = 'unexpected', Object? cause])
    : super(code: 'unexpected', cause: cause);
}
