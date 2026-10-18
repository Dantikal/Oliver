import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Логотип: зелёный квадрат, белая «O» с разрывом и листик.
class OliverLogo extends StatelessWidget {
  const OliverLogo({super.key, this.size = 64, this.withText = false});
  final double size;
  final bool withText;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: size * 0.45,
              offset: Offset(0, size * 0.14))
        ],
      ),
      child: CustomPaint(painter: OliverMarkPainter()),
    );
    if (!withText) {
      return Material(type: MaterialType.transparency, child: mark);
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(height: size * 0.28),
          OliverWordmark(fontSize: size * 0.5),
        ],
      ),
    );
  }
}

/// Надпись «Oliver» с листиком вместо точки над «i».
class OliverWordmark extends StatelessWidget {
  const OliverWordmark({super.key, this.fontSize = 44});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -fontSize * 0.02,
      color: context.isDark ? Colors.white : AppColors.ink,
    );
    final leaf = fontSize * 0.36;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('Ol', style: style),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Точечная «ı», точку заменяет листик.
            Text('ı', style: style),
            Positioned(
              top: fontSize * 0.02,
              left: fontSize * 0.03,
              child: SizedBox(
                width: leaf,
                height: leaf * 0.75,
                child: CustomPaint(painter: _LeafPainter()),
              ),
            ),
          ],
        ),
        Text('ver', style: style),
      ],
    );
  }
}

/// Рисует знак в квадрате размером [Size]. Используется и для иконки.
class OliverMarkPainter extends CustomPainter {
  OliverMarkPainter({this.ring = 1, this.leaf = 1});

  /// Прогресс прорисовки кольца (0..1).
  final double ring;

  /// Масштаб листика (0..1, может перелетать за 1 при пружинке).
  final double leaf;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;

    // Фон — скруглённая «иконка приложения» с глянцевым бликом сверху.
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2ACB64), Color(0xFF14955A), Color(0xFF0A6447)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
        rr.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.25));

    if (ring <= 0) return;

    // Кольцо «O» с разрывом справа сверху.
    final c = Offset(s * 0.49, s * 0.56);
    final r = s * 0.24;
    final stroke = s * 0.16;
    final ringRect = Rect.fromCircle(center: c, radius: r);
    const start = -34 * pi / 180;
    final sweep = 300 * pi / 180 * ring;

    canvas.drawArc(
      ringRect.shift(Offset(0, s * 0.025)),
      start,
      sweep,
      false,
      Paint()
        ..color = const Color(0x40033A26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.025),
    );
    canvas.drawArc(
      ringRect,
      start,
      sweep,
      false,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE3E9E6)],
        ).createShader(ringRect.inflate(stroke / 2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (leaf <= 0) return;

    // Листик растёт из верхнего конца «O».
    canvas.save();
    canvas.translate(s * 0.535, s * 0.37);
    canvas.rotate(-40 * pi / 180);
    canvas.scale(leaf);
    final leafSize = Size(s * 0.37, s * 0.17);
    canvas.translate(0, -leafSize.height / 2);
    _LeafPainter().paint(canvas, leafSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(OliverMarkPainter old) =>
      old.ring != ring || old.leaf != leaf;
}

/// Листик: основание слева по центру, кончик справа.
/// Сезон листика в логотипе.
enum LeafSeason {
  green,
  autumn;

  /// С сентября по ноябрь листик осенний.
  static LeafSeason get current {
    final m = DateTime.now().month;
    return m >= 9 && m <= 11 ? LeafSeason.autumn : LeafSeason.green;
  }

  /// Цвета «искр» для анимаций вокруг листика.
  List<Color> get sparkColors => this == LeafSeason.autumn
      ? const [Color(0xFFFFC23D), Color(0xFFF2762E), Color(0xFFC8372D)]
      : const [AppColors.lime, AppColors.primary];
}

/// Листик: основание слева по центру, кончик справа.
class _LeafPainter extends CustomPainter {
  _LeafPainter([LeafSeason? season]) : season = season ?? LeafSeason.current;
  final LeafSeason season;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.62)
      ..cubicTo(w * 0.18, -h * 0.05, w * 0.7, -h * 0.12, w, 0)
      ..cubicTo(w * 0.86, h * 0.6, w * 0.42, h * 1.15, 0, h * 0.62)
      ..close();
    final bounds = Offset.zero & size;
    final stroke = max(1.0, h * 0.07);

    if (season == LeafSeason.green) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF8BE04A), Color(0xFF3FB833)],
          ).createShader(bounds),
      );
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.1, h * 0.58)
          ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.82, h * 0.14),
        Paint()
          ..color = const Color(0xFF2E9A2A)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
      return;
    }

    // Осень: черешок, золото → оранжевый → багрянец, жилки и блик.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.04, h * 0.6)
        ..quadraticBezierTo(-w * 0.05, h * 0.7, -w * 0.1, h * 0.92),
      Paint()
        ..color = const Color(0xFF7A3B1A)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 1.1,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFC93F), Color(0xFFF58A2E), Color(0xFFD9452B)],
          stops: [0, 0.5, 1],
        ).createShader(bounds),
    );
    // Багряный край снизу — лист «подгорел» с одной стороны.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00B22A22),
            const Color(0xFFB22A22).withValues(alpha: 0.55),
          ],
          stops: const [0.55, 1],
        ).createShader(bounds),
    );
    // Мягкий блик сверху.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.3, -h * 0.05, w * 0.5, h * 0.4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.12),
    );
    canvas.restore();

    final veinPaint = Paint()
      ..color = const Color(0xFF9A2B1C).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Центральная жилка.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.6)
        ..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.86, h * 0.12),
      veinPaint..strokeWidth = stroke,
    );
    // Тонкий тёмный контур.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8E2A1E).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.5,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.season != season;
}
