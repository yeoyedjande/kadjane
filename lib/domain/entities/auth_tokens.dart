/// Jetons de session émis par le backend.
///
/// Ils ne sont jamais journalisés et sont stockés uniquement dans le
/// `SecureTokenStore` (Keychain iOS / EncryptedSharedPreferences Android).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Vrai quand la session expire dans moins de 2 minutes : il faut rafraîchir.
  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) => AuthTokens(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  @override
  String toString() => 'AuthTokens(expiresAt: $expiresAt)';
}
