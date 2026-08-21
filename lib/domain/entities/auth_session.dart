import 'package:kadjane/domain/entities/auth_tokens.dart';
import 'package:kadjane/domain/entities/user.dart';

/// Session authentifiée : utilisateur courant + jetons.
class AuthSession {
  const AuthSession({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;

  AuthSession copyWith({User? user, AuthTokens? tokens}) =>
      AuthSession(user: user ?? this.user, tokens: tokens ?? this.tokens);
}
