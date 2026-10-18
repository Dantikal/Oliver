import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

/// Едва заметное «бумажное» зерно поверх всего интерфейса.
/// Рисуется один раз (RepaintBoundary) и не ловит касания.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _GrainPainter(dark)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final count = (size.width * size.height / 90).round();
    final light = <Offset>[];
    final shade = <Offset>[];
    for (var i = 0; i < count; i++) {
      final o =
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      (rnd.nextBool() ? light : shade).add(o);
    }
    final a = dark ? 0.035 : 0.045;
    canvas.drawPoints(
        PointMode.points,
        shade,
        Paint()
          ..color = Colors.black.withValues(alpha: a)
          ..strokeWidth = 1.1);
    canvas.drawPoints(
        PointMode.points,
        light,
        Paint()
          ..color = Colors.white.withValues(alpha: a * 1.4)
          ..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.dark != dark;
}
