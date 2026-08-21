import 'dart:io';

import 'package:flutter/widgets.dart';

/// Implémentation mobile/desktop : lecture depuis le système de fichiers.
ImageProvider<Object>? localImageProvider(String path) => FileImage(File(path));
