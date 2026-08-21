import 'package:flutter/material.dart';
import 'package:kadjane/core/extensions/context_extensions.dart';
import 'package:kadjane/core/utils/local_image_provider.dart';
import 'package:kadjane/design_system/theme/app_dimensions.dart';

/// Avatar d'un membre ou d'une organisation.
///
/// Sans photo, on affiche les initiales sur un fond dérivé du nom : deux
/// membres différents n'ont jamais la même couleur par hasard.
class KAvatar extends StatelessWidget {
  const KAvatar({
    required this.name,
    super.key,
    this.imageUrl,
    this.size = KSizes.avatarMd,
    this.highlighted = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = context.colors.wheelColors;
    final Color background = palette[name.hashCode.abs() % palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background.withValues(alpha: context.isDark ? 0.30 : 0.16),
        shape: BoxShape.circle,
        border: highlighted
            ? Border.all(color: context.colors.accent, width: 2)
            : null,
        image: _imageProvider() != null
            ? DecorationImage(image: _imageProvider()!, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: _imageProvider() != null
          ? null
          : Text(
              _initials(name),
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: context.isDark
                    ? background
                    : Color.lerp(background, Colors.black, 0.25),
              ),
            ),
    );
  }

  ImageProvider<Object>? _imageProvider() => resolveImageProvider(imageUrl);

  static String _initials(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}
