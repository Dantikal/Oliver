import 'package:flutter/material.dart';

/// Палитра бренда: изумрудный, глубокий лесной, электрический лайм.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1F7A4C);
  static const primaryDeep = Color(0xFF125A37);
  static const forest = Color(0xFF0A2A1F);
  static const leaf = Color(0xFF6E9440);
  static const mint = Color(0xFF9CCB7E);
  static const lime = Color(0xFFC5F04F);
  static const teal = Color(0xFF3E8B78);
  static const ink = Color(0xFF0D1712);
  static const cream = Color(0xFFF6F3EA);
  static const success = Color(0xFF2FA35A);
  static const warning = Color(0xFFF0B429);
  static const danger = Color(0xFFE5484D);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27925C), Color(0xFF125A37)],
  );

  static const limeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDDFF7A), Color(0xFFADE33A)],
  );

  static const leafGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9CCB7E), Color(0xFF5E8A34)],
  );

  static const forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14432F), Color(0xFF071F16)],
  );

  /// Пятна aurora-фона.
  static const aurora = [
    Color(0xFF1F7A4C),
    Color(0xFFC5F04F),
    Color(0xFF3E8B78),
    Color(0xFF9CCB7E),
  ];

  /// Набор природных акцентов для категорий/иконок.
  static const accents = [
    Color(0xFF1F7A4C),
    Color(0xFF6E9440),
    Color(0xFF3E8B78),
    Color(0xFFB07D3C),
    Color(0xFF5E8A34),
    Color(0xFF0E4A34),
    Color(0xFF7C9A4F),
    Color(0xFF2F7F6B),
  ];
}

/// Скругления — одна шкала на всё приложение.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Многослойные мягкие тени: «контактная» + рассеянная.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(Color shadow, {double lift = 1}) => [
        BoxShadow(
            color: shadow,
            blurRadius: 28 * lift,
            spreadRadius: -6,
            offset: Offset(0, 14 * lift)),
        BoxShadow(
            color: shadow.withValues(alpha: shadow.a * 0.6),
            blurRadius: 3,
            offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> glow(Color c, {double strength = 1}) => [
        BoxShadow(
            color: c.withValues(alpha: 0.45 * strength),
            blurRadius: 24 * strength,
            spreadRadius: -4,
            offset: Offset(0, 10 * strength)),
      ];
}
