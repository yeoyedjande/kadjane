import 'package:kadjane/domain/entities/attachment.dart';

/// Fichier sélectionné localement, avant envoi.
class LocalFile {
  const LocalFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
}

/// Interface de stockage des justificatifs.
///
/// Le MVP conserve simplement le chemin local. L'implémentation distante
/// (S3 / MinIO) viendra remplacer [LocalFileStorage] sans impacter les écrans.
abstract interface class FileStorage {
  Future<Attachment> upload(LocalFile file);

  Future<void> delete(String attachmentId);

  /// URL affichable pour une pièce jointe (locale ou distante).
  String? resolveUrl(Attachment attachment);
}

class LocalFileStorage implements FileStorage {
  LocalFileStorage(this._idGenerator);

  final String Function() _idGenerator;
  final Map<String, Attachment> _attachments = <String, Attachment>{};

  @override
  Future<Attachment> upload(LocalFile file) async {
    final Attachment attachment = Attachment(
      id: _idGenerator(),
      fileName: file.fileName,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      localPath: file.path,
      uploadedAt: DateTime.now(),
    );
    _attachments[attachment.id] = attachment;
    return attachment;
  }

  @override
  Future<void> delete(String attachmentId) async {
    _attachments.remove(attachmentId);
  }

  @override
  String? resolveUrl(Attachment attachment) =>
      attachment.remoteUrl ?? attachment.localPath;
}

// TODO(api): implémenter `S3FileStorage` (upload signé, suppression logique,
// URL pré-signées) une fois le service objet disponible.
