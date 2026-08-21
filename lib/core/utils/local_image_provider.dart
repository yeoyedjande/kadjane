import 'package:flutter/widgets.dart';

import 'local_image_provider_io.dart'
    if (dart.library.js_interop) 'local_image_provider_web.dart'
    as platform;

/// Résout un chemin d'image en `ImageProvider`.
///
/// Les URL distantes fonctionnent partout ; les chemins locaux ne sont
/// disponibles que sur mobile/desktop. L'import conditionnel garde donc la
/// compilation web possible (objectif « Flutter Web plus tard »).
ImageProvider<Object>? resolveImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return null;
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  return platform.localImageProvider(path);
}
