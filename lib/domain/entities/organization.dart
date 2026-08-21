import 'package:kadjane/domain/enums/currency.dart';

/// Règles de fonctionnement propres à une organisation.
class OrganizationSettings {
  const OrganizationSettings({
    this.requireFullPaymentBeforeDraw = true,
    this.allowDrawOverride = true,
    this.latePaymentGraceDays = 3,
    this.notifyBeforeDueDays = 3,
  });

  /// Le tirage n'est autorisé que si toutes les cotisations du cycle sont
  /// réglées (règle par défaut de Kadjane).
  final bool requireFullPaymentBeforeDraw;

  /// Autorise un administrateur à forcer le tirage. Le forçage est audité.
  final bool allowDrawOverride;

  /// Nombre de jours de tolérance après l'échéance avant de marquer un retard.
  final int latePaymentGraceDays;

  /// Délai de rappel avant échéance (notifications).
  final int notifyBeforeDueDays;

  OrganizationSettings copyWith({
    bool? requireFullPaymentBeforeDraw,
    bool? allowDrawOverride,
    int? latePaymentGraceDays,
    int? notifyBeforeDueDays,
  }) => OrganizationSettings(
    requireFullPaymentBeforeDraw:
        requireFullPaymentBeforeDraw ?? this.requireFullPaymentBeforeDraw,
    allowDrawOverride: allowDrawOverride ?? this.allowDrawOverride,
    latePaymentGraceDays: latePaymentGraceDays ?? this.latePaymentGraceDays,
    notifyBeforeDueDays: notifyBeforeDueDays ?? this.notifyBeforeDueDays,
  );
}

/// Espace d'une association, amicale, famille ou groupe de tontine.
///
/// Toutes les données (membres, tontines, cotisations, audit) sont cloisonnées
/// par `organizationId`.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdAt,
    this.description,
    this.logoUrl,
    this.country = 'CI',
    this.phone,
    this.email,
    this.address,
    this.rules,
    this.settings = const OrganizationSettings(),
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final Currency currency;
  final String country;
  final String? phone;
  final String? email;
  final String? address;

  /// Règlement intérieur libre.
  final String? rules;
  final OrganizationSettings settings;
  final DateTime createdAt;

  String get initials {
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Organization copyWith({
    String? name,
    String? description,
    String? logoUrl,
    Currency? currency,
    String? country,
    String? phone,
    String? email,
    String? address,
    String? rules,
    OrganizationSettings? settings,
  }) => Organization(
    id: id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    createdAt: createdAt,
    description: description ?? this.description,
    logoUrl: logoUrl ?? this.logoUrl,
    country: country ?? this.country,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    rules: rules ?? this.rules,
    settings: settings ?? this.settings,
  );
}
