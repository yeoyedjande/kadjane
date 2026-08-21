/// Document d'organisation (statuts, règlement, PV de réunion...).
///
/// Le module documentaire complet est prévu après le MVP ; l'entité existe déjà
/// pour que le stockage et les rapports puissent s'y référer.
class Document {
  const Document({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.attachmentId,
    required this.createdAt,
    this.category = 'general',
    this.createdBy,
  });

  final String id;
  final String organizationId;
  final String title;
  final String attachmentId;
  final String category;
  final String? createdBy;
  final DateTime createdAt;
}
