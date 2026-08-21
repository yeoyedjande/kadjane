import 'package:kadjane/domain/enums/member_enums.dart';

/// Compte utilisateur Kadjane.
///
/// Un utilisateur peut appartenir à plusieurs organisations : ses données
/// personnelles sont donc indépendantes de toute organisation.
///
/// Note d'implémentation : les entités ne redéfinissent volontairement pas
/// `==`. L'égalité par référence garantit qu'une mise à jour d'état
/// (Riverpod) déclenche toujours un rafraîchissement de l'interface.
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.createdAt,
    this.email,
    this.avatarUrl,
    this.gender = Gender.unspecified,
    this.birthDate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final Gender gender;
  final DateTime? birthDate;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final String a = firstName.isNotEmpty ? firstName[0] : '';
    final String b = lastName.isNotEmpty ? lastName[0] : '';
    final String value = '$a$b'.trim();
    return value.isEmpty ? '?' : value.toUpperCase();
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? avatarUrl,
    Gender? gender,
    DateTime? birthDate,
  }) => User(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    createdAt: createdAt,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    gender: gender ?? this.gender,
    birthDate: birthDate ?? this.birthDate,
  );
}
