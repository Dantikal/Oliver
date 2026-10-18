import 'dart:math';

import 'package:flutter/material.dart';

import '../vibe/vibe.dart';
import '../theme/app_palette.dart';

/// Живой aurora-фон: крупные мягкие пятна плывут по лиссажу.
/// [base] — подложка (по умолчанию фон темы), [intensity] — яркость пятен.
class AnimatedBlobs extends StatefulWidget {
  const AnimatedBlobs(
      {super.key,
      this.base,
      this.intensity = 1,
      this.fadeBottom = false,
      this.period = const Duration(seconds: 18)});
  final Color? base;
  final double intensity;

  /// Нижняя половина плавно растворяется в цвет подложки.
  final bool fadeBottom;
  final Duration period;

  @override
  State<AnimatedBlobs> createState() => _AnimatedBlobsState();
}

class _AnimatedBlobsState extends State<AnimatedBlobs>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark || widget.base != null;
    // Палитра пятен меняется вместе с «вайбом» (осень, зима…).
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, auroraColors]),
        builder: (_, __) => CustomPaint(
          painter: _BlobPainter(
              _c.value * 2 * pi,
              dark,
              widget.base ?? context.palette.bg,
              widget.intensity,
              widget.fadeBottom,
              auroraColors.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(
      this.t, this.dark, this.bg, this.intensity, this.fade, this.colors);
  final double t;
  final bool dark;
  final Color bg;
  final double intensity;
  final bool fade;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, Paint()..color = bg);
    final a = (dark ? 0.62 : 0.38) * intensity;
    void blob(Color c, double cx, double cy, double r, double alpha) {
      final center = Offset(cx * s.width, cy * s.height);
      final radius = r * max(s.width, s.height * 0.6);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            c.withValues(alpha: alpha),
            c.withValues(alpha: alpha * 0.35),
            c.withValues(alpha: 0),
          ], stops: const [
            0,
            0.45,
            1
          ]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final c = colors;
    blob(c[0], 0.12 + 0.14 * sin(t), 0.10 + 0.08 * cos(t * 2), 0.95, a);
    blob(c[1], 0.92 + 0.10 * cos(t * 1.5), 0.24 + 0.10 * sin(t), 0.72,
        a * (dark ? 0.55 : 0.75));
    blob(c[2], 0.30 + 0.18 * cos(t), 0.92 + 0.06 * sin(t * 2), 0.85, a);
    blob(c[3], 0.82 + 0.10 * sin(t * 2), 0.80 + 0.08 * cos(t), 0.6, a * 0.8);
    if (fade) {
      final r = Rect.fromLTWH(0, s.height * 0.35, s.width, s.height * 0.65);
      canvas.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg.withValues(alpha: 0), bg],
            ).createShader(r));
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.t != t || old.dark != dark || old.bg != bg || old.colors != colors;
}
