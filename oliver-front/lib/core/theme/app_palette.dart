import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.glass,
    required this.shadow,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color glass;
  final Color shadow;

  static const light = AppPalette(
    bg: Color(0xFFF4F4EE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECEDE5),
    surface3: Color(0xFFDADDD1),
    border: Color(0x170D1712),
    text: Color(0xFF0D1712),
    textSecondary: Color(0xFF4F5A52),
    textTertiary: Color(0xFF8D978D),
    shimmerBase: Color(0xFFE7E8E0),
    shimmerHighlight: Color(0xFFF8F8F4),
    glass: Color(0xB8FFFFFF),
    shadow: Color(0x1F0D2A1C),
  );

  /// Песочная: тёплый беж, коричневатый текст, тот же изумруд.
  static const sand = AppPalette(
    bg: Color(0xFFEFE3CB),
    surface: Color(0xFFFAF3E4),
    surface2: Color(0xFFE5D6B8),
    surface3: Color(0xFFD3BF98),
    border: Color(0x1F3A2A17),
    text: Color(0xFF2B2114),
    textSecondary: Color(0xFF65543B),
    textTertiary: Color(0xFF9C8664),
    shimmerBase: Color(0xFFE2D3B4),
    shimmerHighlight: Color(0xFFF3EAD7),
    glass: Color(0xBFFAF3E4),
    shadow: Color(0x263A2A17),
  );

  static const dark = AppPalette(
    bg: Color(0xFF060A08),
    surface: Color(0xFF101612),
    surface2: Color(0xFF18201A),
    surface3: Color(0xFF232E25),
    border: Color(0x17FFFFFF),
    text: Color(0xFFEFF3EE),
    textSecondary: Color(0xFFA9B3A9),
    textTertiary: Color(0xFF6D786E),
    shimmerBase: Color(0xFF131A15),
    shimmerHighlight: Color(0xFF1E2820),
    glass: Color(0xA6121A15),
    shadow: Color(0x99000000),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      border: l(border, other.border),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
      glass: l(glass, other.glass),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension ThemeContextX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
