import 'package:kadjane/core/error/app_exception.dart';
import 'package:kadjane/l10n/generated/app_localizations.dart';

/// Traduit une exception technique en message affichable.
///
/// Aucun écran ne montre un message brut : tout passe par ce mapper, ce qui
/// évite de divulguer des détails techniques à l'utilisateur.
class ErrorMapper {
  const ErrorMapper._();

  static String message(AppLocalizations l10n, Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_otp':
          return l10n.authInvalidOtp;
        case 'session_expired':
          return l10n.commonErrorGeneric;
        default:
          return l10n.authInvalidCredentials;
      }
    }
    if (error is OfflineException) {
      return l10n.commonOfflineMessage;
    }
    if (error is NetworkException) {
      return l10n.commonErrorGeneric;
    }
    if (error is PermissionDeniedException) {
      return l10n.orgNoPermission;
    }
    if (error is ValidationException) {
      return _validationMessage(l10n, error);
    }
    if (error is BusinessRuleException) {
      return _businessMessage(l10n, error);
    }
    return l10n.commonErrorGeneric;
  }

  static String _validationMessage(
    AppLocalizations l10n,
    ValidationException error,
  ) {
    switch (error.message) {
      case 'password_too_short':
        return l10n.authPasswordTooShort;
      case 'phone_already_used':
        return l10n.authInvalidPhone;
      case 'min_two_participants':
        return l10n.tontinesMinParticipants;
      default:
        return l10n.commonErrorGeneric;
    }
  }

  static String _businessMessage(
    AppLocalizations l10n,
    BusinessRuleException error,
  ) {
    switch (error.code) {
      case 'missingContributions':
        final Object? missing = error.details?['missing'];
        return l10n.drawUnavailableReason(missing is int ? missing : 0);
      case 'alreadyDrawn':
        return l10n.drawAlreadyDone;
      case 'noEligibleParticipant':
      case 'draw.no_eligible':
        return l10n.drawNoEligible;
      case 'orderAlreadyDefined':
        return l10n.allocationFullOrderDesc;
      default:
        return l10n.commonErrorGeneric;
    }
  }
}
