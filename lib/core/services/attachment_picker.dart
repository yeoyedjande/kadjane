import 'package:image_picker/image_picker.dart';
import 'package:kadjane/core/storage/file_storage.dart';

/// Sélection d'un justificatif depuis l'appareil photo ou la galerie.
///
/// L'interface reste indépendante du plugin : elle pourra accueillir la
/// sélection de documents (PDF) sans impacter les écrans.
abstract interface class AttachmentPicker {
  Future<LocalFile?> pickFromCamera();

  Future<LocalFile?> pickFromGallery();
}

class ImageAttachmentPicker implements AttachmentPicker {
  ImageAttachmentPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LocalFile?> pickFromCamera() => _pick(ImageSource.camera);

  @override
  Future<LocalFile?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<LocalFile?> _pick(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) {
      return null;
    }
    return LocalFile(
      path: file.path,
      fileName: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
      sizeBytes: await file.length(),
    );
  }
}
