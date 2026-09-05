import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';

/// Cotisations de caisse : ce que les membres doivent à leur association.
///
/// Trois usages, séparés par les droits. Un membre consulte sa propre
/// situation ([myOutstanding]). Le trésorier voit l'ensemble et encaisse
/// (`dues.record`). Enfin, il définit les cotisations elles-mêmes
/// (`dues.manage`) : c'est lui qui tient la caisse, il n'a pas à attendre le
/// back-office pour ouvrir une cotisation.
abstract interface class DuesRepository {
  /// Échéances non soldées du membre connecté, les plus anciennes d'abord.
  Future<List<DuesEntry>> myOutstanding(String organizationId);

  /// Cotisations définies par l'organisation, avec leur synthèse.
  Future<List<DuesPlan>> plans(String organizationId);

  /// Échéances d'une cotisation, tous membres confondus.
  ///
  /// [period] filtre sur un numéro de période ; omis, toutes remontent.
  Future<List<DuesEntry>> entries(
    String organizationId,
    String planId, {
    int? period,
  });

  /// Ouvre une cotisation périodique. Réservé à `dues.manage`.
  Future<DuesPlan> createPlan(String organizationId, DuesPlanDraft draft);

  /// Modifie une cotisation. Réservé à `dues.manage`.
  ///
  /// Chaque champ omis reste inchangé. Un nouveau montant ne vaut que pour les
  /// périodes **à venir** : réécrire le passé fausserait les comptes.
  Future<DuesPlan> updatePlan(
    String organizationId,
    String planId, {
    String? name,
    double? amount,
    String? description,
    int? dueDay,
    DuesPlanStatus? status,
  });

  /// Enregistre un encaissement. Réservé à `dues.record`.
  Future<void> recordPayment({
    required String entryId,
    required double amount,
    required PaymentMethod method,
    String? reference,
    DateTime? paidAt,
  });
}
