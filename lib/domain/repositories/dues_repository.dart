import 'package:kadjane/domain/entities/dues_entry.dart';
import 'package:kadjane/domain/enums/payment_enums.dart';

/// Cotisations de caisse : ce que les membres doivent à leur association.
///
/// Deux usages, séparés par les droits. Un membre consulte sa propre situation
/// ([myOutstanding]). Le trésorier, lui, voit l'ensemble et encaisse — les
/// plans se créent en revanche depuis le back-office.
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

  /// Enregistre un encaissement. Réservé à `dues.record`.
  Future<void> recordPayment({
    required String entryId,
    required double amount,
    required PaymentMethod method,
    String? reference,
  });
}
