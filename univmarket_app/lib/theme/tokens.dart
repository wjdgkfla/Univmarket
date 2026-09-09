import 'package:flutter/material.dart';

/// Design tokens mirroring the confirmed "Variant C: Bento" web prototype —
/// cool graphite neutrals, single coral accent, ambient gradient glow.
class AppColors {
  final Color bg, surface, surface2, ink, inkSoft, inkFaint, line;
  final Color accent, accentDeep, accentInk, accentWash;
  final Color violet, pink;
  final Color good, goodWash, warn, warnWash, bad, badWash;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.accent,
    required this.accentDeep,
    required this.accentInk,
    required this.accentWash,
    required this.violet,
    required this.pink,
    required this.good,
    required this.goodWash,
    required this.warn,
    required this.warnWash,
    required this.bad,
    required this.badWash,
  });

  static const light = AppColors(
    bg: Color(0xFFF8F9F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEBEDF1),
    ink: Color(0xFF15161B),
    inkSoft: Color(0xFF5A616F),
    inkFaint: Color(0xFF69717E),
    line: Color(0xFFE5E7EE),
    accent: Color(0xFFBD431D),
    accentDeep: Color(0xFFD43C13),
    accentInk: Color(0xFFFFFFFF),
    accentWash: Color(0xFFFDE7DF),
    violet: Color(0xFF8B5CF6),
    pink: Color(0xFFEC4899),
    good: Color(0xFF158F4C),
    goodWash: Color(0xFFE2F5EA),
    warn: Color(0xFFC8710A),
    warnWash: Color(0xFFFAEDDB),
    bad: Color(0xFFD2281D),
    badWash: Color(0xFFFBE6E4),
  );

  static const dark = AppColors(
    bg: Color(0xFF0C0D10),
    surface: Color(0xFF18191E),
    surface2: Color(0xFF212328),
    ink: Color(0xFFF2F1EE),
    inkSoft: Color(0xFFB2AFA9),
    inkFaint: Color(0xFF726F6A),
    line: Color(0xFF2B2D33),
    accent: Color(0xFFFF6A3D),
    accentDeep: Color(0xFFFF8A5F),
    accentInk: Color(0xFF16110D),
    accentWash: Color(0xFF33201A),
    violet: Color(0xFFA78BFA),
    pink: Color(0xFFF472B6),
    good: Color(0xFF3ECB87),
    goodWash: Color(0xFF123322),
    warn: Color(0xFFE6A24F),
    warnWash: Color(0xFF39280F),
    bad: Color(0xFFF0776C),
    badWash: Color(0xFF3A1A17),
  );
}

class AppRadius {
  static const card = 20.0;
  static const sm = 14.0;
  static const pill = 999.0;
}

/// Category art mesh gradients — three-stop, matching the web prototype's tiles.
const Map<String, List<Color>> categoryMesh = {
  'book': [Color(0xFFFFE3D6), Color(0xFFFF9A6E), Color(0xFFBD431D)],
  'headphones': [Color(0xFFE8E2FB), Color(0xFFB39DFB), Color(0xFF7C5FE0)],
  'chair': [Color(0xFFFDE8CF), Color(0xFFF4BD7A), Color(0xFFE08A2E)],
  'bike': [Color(0xFFDCF3E5), Color(0xFF7FD9A8), Color(0xFF1C9A5B)],
  'lamp': [Color(0xFFFDECCB), Color(0xFFF3C876), Color(0xFFE0A02C)],
  'shirt': [Color(0xFFFBE1E8), Color(0xFFF2A0BE), Color(0xFFE0567F)],
  'bag': [Color(0xFFE7E6FB), Color(0xFFA89AF0), Color(0xFF6A5FD8)],
  'board': [Color(0xFFDCEAF7), Color(0xFF8BBDE9), Color(0xFF2E79C9)],
};

extension AppColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
