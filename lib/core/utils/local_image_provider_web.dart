import 'package:flutter/widgets.dart';

/// Implémentation web : pas d'accès au système de fichiers.
///
/// Sur le web, `image_picker` renvoie une URL blob directement utilisable.
ImageProvider<Object>? localImageProvider(String path) =>
    path.startsWith('blob:') ? NetworkImage(path) : null;
