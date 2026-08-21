import 'package:flutter/material.dart';

/// Ombres douces et discrètes, adaptées au fond clair ou sombre.
class KShadows {
  const KShadows._();

  static List<BoxShadow> card(Brightness brightness) => <BoxShadow>[
    BoxShadow(
      color: brightness == Brightness.light
          ? const Color(0xFF16211D).withValues(alpha: 0.05)
          : const Color(0xFF000000).withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> raised(Brightness brightness) => <BoxShadow>[
    BoxShadow(
      color: brightness == Brightness.light
          ? const Color(0xFF16211D).withValues(alpha: 0.10)
          : const Color(0xFF000000).withValues(alpha: 0.45),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> glow(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];
}
