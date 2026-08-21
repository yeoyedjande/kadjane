import 'package:kadjane/domain/entities/auth_session.dart';
import 'package:kadjane/domain/entities/user.dart';
import 'package:kadjane/domain/enums/member_enums.dart';

/// Données d'inscription.
class RegisterDraft {
  const RegisterDraft({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.password,
    this.email,
    this.gender = Gender.unspecified,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String password;
  final String? email;
  final Gender gender;
}

/// Contrat d'authentification.
///
/// L'implémentation mock permet de faire tourner toute l'application sans
/// backend ; l'implémentation REST viendra s'y substituer.
abstract interface class AuthRepository {
  /// Connexion par téléphone ou email.
  Future<AuthSession> signIn({
    required String identifier,
    required String password,
  });

  Future<AuthSession> register(RegisterDraft draft);

  /// Envoie un code de vérification (SMS/email).
  Future<void> requestOtp(String target);

  /// Vérifie le code et retourne un jeton de réinitialisation à usage unique.
  Future<String> verifyOtp({required String target, required String code});

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  /// Restaure la session depuis le stockage sécurisé (démarrage de l'app).
  Future<AuthSession?> restoreSession();

  /// Renouvelle les jetons expirés.
  Future<AuthSession> refreshSession();

  Future<void> signOut();

  Future<User> updateProfile(User user);
}
