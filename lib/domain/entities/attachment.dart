/// Pièce jointe (justificatif de paiement, logo, document...).
class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.localPath,
    this.remoteUrl,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  /// Chemin sur l'appareil tant que l'envoi distant n'a pas eu lieu.
  final String? localPath;

  /// URL renvoyée par le service de stockage objet (S3/MinIO).
  final String? remoteUrl;

  bool get isImage => mimeType.startsWith('image/');

  bool get isSynced => remoteUrl != null;

  Attachment copyWith({String? remoteUrl}) => Attachment(
    id: id,
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    uploadedAt: uploadedAt,
    localPath: localPath,
    remoteUrl: remoteUrl ?? this.remoteUrl,
  );
}
