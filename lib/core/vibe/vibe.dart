import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';
import '../theme/app_colors.dart';

/// Настроение приложения: анимация поверх интерфейса + палитра aurora-фона.
enum Vibe {
  off,
  auto,
  autumn,
  winter,
  spring,
  summer,
  night;

  /// «Авто» — по времени года.
  Vibe get resolved {
    if (this != auto) return this;
    return switch (DateTime.now().month) {
      12 || 1 || 2 => winter,
      3 || 4 || 5 => spring,
      6 || 7 || 8 => summer,
      _ => autumn,
    };
  }

  String get l10nKey => 'vibe_$name';

  /// Цвета пятен aurora-фона под настроение.
  List<Color> get aurora => switch (resolved) {
        autumn => const [
            Color(0xFFC8622D),
            Color(0xFFFFC23D),
            Color(0xFF8A5A3B),
            Color(0xFFE9A23B)
          ],
        winter => const [
            Color(0xFF5B8FD9),
            Color(0xFFDDEBFF),
            Color(0xFF7FB3D5),
            Color(0xFFB8C9E8)
          ],
        spring => const [
            Color(0xFFF5A3C0),
            AppColors.lime,
            Color(0xFFFFD6E4),
            AppColors.mint
          ],
        summer => const [
            Color(0xFFFFB938),
            AppColors.lime,
            AppColors.success,
            Color(0xFFFFE27A)
          ],
        night => const [
            Color(0xFF3B2A6B),
            Color(0xFF5B4BC4),
            Color(0xFF1F5F4A),
            Color(0xFF8E6CEF)
          ],
        _ => AppColors.aurora,
      };
}

/// Палитра aurora-фона, которую слушает [AnimatedBlobs].
final auroraColors = ValueNotifier<List<Color>>(AppColors.aurora);

final vibeProvider = NotifierProvider<VibeNotifier, Vibe>(VibeNotifier.new);

class VibeNotifier extends Notifier<Vibe> {
  static const _key = 'vibe';

  @override
  Vibe build() {
    final v = ref.read(sharedPrefsProvider).getString(_key);
    final vibe =
        Vibe.values.firstWhere((x) => x.name == v, orElse: () => Vibe.off);
    auroraColors.value = vibe.aurora;
    return vibe;
  }

  void set(Vibe v) {
    state = v;
    auroraColors.value = v.aurora;
    ref.read(sharedPrefsProvider).setString(_key, v.name);
  }
}

/// Порыв ветра от касания: частицы разлетаются от точки.
final _gust = ValueNotifier<(Offset, int)?>(null);
int _gustId = 0;

/// Оборачивает приложение: слой частиц поверх (не ловит касания)
/// и «ветер» от любого касания экрана.
class VibeOverlay extends ConsumerWidget {
  const VibeOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = ref.watch(vibeProvider).resolved;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (vibe == Vibe.off || reduce) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _gust.value = (e.position, ++_gustId),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: VibeLayer(vibe: vibe, listenGust: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _P {
  double x = 0, y = 0;
  double size = 0, depth = 1;
  double rot = 0, vr = 0;
  double phase = 0;
  double ex = 0, ey = 0; // импульс от ветра
  Color color = Colors.white;
}

/// Слой частиц. [compact] — превью в настройках (меньше частиц, без гирлянды).
class VibeLayer extends StatefulWidget {
  const VibeLayer(
      {super.key,
      required this.vibe,
      this.compact = false,
      this.listenGust = false});
  final Vibe vibe;
  final bool compact;
  final bool listenGust;

  @override
  State<VibeLayer> createState() => _VibeLayerState();
}

class _VibeLayerState extends State<VibeLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = _Frame();
  final _rnd = Random();
  final List<_P> _ps = [];
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _t = 0;

  // Падающая звезда (ночь): позиция старта, прогресс, пауза до следующей.
  double _shootT = -1, _shootWait = 3;
  Offset _shootFrom = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    if (widget.listenGust) _gust.addListener(_onGust);
  }

  @override
  void didUpdateWidget(VibeLayer old) {
    super.didUpdateWidget(old);
    if (old.vibe != widget.vibe) _ps.clear();
  }

  @override
  void dispose() {
    _gust.removeListener(_onGust);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  int get _count {
    final n = switch (widget.vibe) {
      Vibe.autumn => 16,
      Vibe.winter => 70,
      Vibe.spring => 22,
      Vibe.summer => 18,
      Vibe.night => 55,
      _ => 0,
    };
    return widget.compact ? (n * 0.3).ceil() : n;
  }

  List<Color> get _colors => switch (widget.vibe) {
        Vibe.autumn => const [
            Color(0xFFFFC23D),
            Color(0xFFF2762E),
            Color(0xFFC8372D),
            Color(0xFFE9A23B),
            Color(0xFFB5651D),
          ],
        Vibe.spring => const [
            Color(0xFFF9B8CF),
            Color(0xFFF5A3C0),
            Color(0xFFFFD6E4),
            Color(0xFFFFFFFF),
          ],
        _ => const [Colors.white],
      };

  void _spawn(_P p, {required bool initial}) {
    final w = _size.width, h = _size.height;
    p
      ..depth = 0.45 + _rnd.nextDouble() * 0.55
      ..phase = _rnd.nextDouble() * pi * 2
      ..rot = _rnd.nextDouble() * pi * 2
      ..vr = (_rnd.nextDouble() - 0.5) * 2.4
      ..ex = 0
      ..ey = 0
      ..color = _colors[_rnd.nextInt(_colors.length)];
    switch (widget.vibe) {
      case Vibe.summer:
        p
          ..x = _rnd.nextDouble() * w
          ..y = h * (0.15 + _rnd.nextDouble() * 0.8)
          ..size = 2 + _rnd.nextDouble() * 1.6;
      case Vibe.night:
        p
          ..x = _rnd.nextDouble() * w
          ..y = _rnd.nextDouble() * h * 0.55
          ..size = 0.8 + pow(_rnd.nextDouble(), 3) * 2.6;
      default:
        p
          ..x = _rnd.nextDouble() * w
          ..y = initial ? _rnd.nextDouble() * h : -30 - _rnd.nextDouble() * 60
          ..size = switch (widget.vibe) {
            Vibe.autumn => 14 + _rnd.nextDouble() * 12,
            Vibe.spring => 8 + _rnd.nextDouble() * 6,
            _ => 1.2 + _rnd.nextDouble() * 2.4,
          };
    }
    if (widget.compact) p.size *= widget.vibe == Vibe.night ? 1 : 0.7;
  }

  void _onGust() {
    final g = _gust.value;
    if (g == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final at = box.globalToLocal(g.$1);
    for (final p in _ps) {
      final d = Offset(p.x, p.y) - at;
      final dist = d.distance;
      if (dist > 170 || dist < 1) continue;
      final f = (1 - dist / 170) * 520;
      p
        ..ex += d.dx / dist * f
        ..ey += d.dy / dist * f
        ..vr += (_rnd.nextDouble() - 0.5) * 8;
    }
  }

  void _tick(Duration elapsed) {
    if (_size.isEmpty) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    while (_ps.length < _count) {
      _ps.add(_P());
      _spawn(_ps.last, initial: true);
    }
    final w = _size.width, h = _size.height;
    final speed = widget.compact ? 0.45 : 1.0;
    for (final p in _ps) {
      final damp = exp(-dt * 2.2);
      p
        ..ex *= damp
        ..ey *= damp
        ..rot += p.vr * dt;
      p.vr *= exp(-dt * 0.5);
      if (p.vr.abs() < 0.3) p.vr = p.vr.isNegative ? -0.3 : 0.3;
      switch (widget.vibe) {
        case Vibe.autumn:
          p.x += (sin(_t * 1.3 + p.phase) * 26 * p.depth + p.ex) * dt;
          p.y += ((30 + 42 * p.depth) * speed + p.ey) * dt;
        case Vibe.spring:
          p.x += (14 + sin(_t * 1.8 + p.phase) * 20 + p.ex) * dt * speed;
          p.y += ((22 + 26 * p.depth) * speed + p.ey) * dt;
        case Vibe.winter:
          p.x += (sin(_t * 0.9 + p.phase) * 12 * p.depth + p.ex) * dt;
          p.y += ((16 + 40 * p.depth) * speed + p.ey) * dt;
        case Vibe.summer:
          p.x += (sin(_t * 0.6 + p.phase) * 16 +
                  cos(_t * 0.37 + p.phase * 2) * 10 +
                  p.ex) *
              dt;
          p.y += (cos(_t * 0.5 + p.phase) * 12 + p.ey) * dt;
          if (p.x < -20) p.x = w + 10;
          if (p.x > w + 20) p.x = -10;
          if (p.y < -20) p.y = h + 10;
          if (p.y > h + 20) p.y = -10;
        case Vibe.night:
          p.x += p.ex * dt;
          p.y += p.ey * dt;
        default:
          break;
      }
      final falls = widget.vibe == Vibe.autumn ||
          widget.vibe == Vibe.spring ||
          widget.vibe == Vibe.winter;
      if (falls && (p.y > h + 30 || p.x < -60 || p.x > w + 60)) {
        _spawn(p, initial: false);
      }
    }
    if (widget.vibe == Vibe.night && !widget.compact) {
      if (_shootT < 0) {
        _shootWait -= dt;
        if (_shootWait <= 0) {
          _shootT = 0;
          _shootFrom = Offset(w * (0.2 + _rnd.nextDouble() * 0.7),
              h * (0.05 + _rnd.nextDouble() * 0.25));
        }
      } else {
        _shootT += dt / 0.9;
        if (_shootT >= 1) {
          _shootT = -1;
          _shootWait = 5 + _rnd.nextDouble() * 6;
        }
      }
    }
    _frame.tick();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = widget.compact ? 0.0 : MediaQuery.paddingOf(context).top;
    return LayoutBuilder(builder: (context, c) {
      final s = c.biggest;
      if (s != _size) {
        final first = _size.isEmpty;
        _size = s;
        if (!first) _ps.clear();
      }
      return RepaintBoundary(
        child: CustomPaint(
          size: s,
          painter: _VibePainter(this, dark: dark, top: top),
        ),
      );
    });
  }
}

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _VibePainter extends CustomPainter {
  _VibePainter(this.s, {required this.dark, required this.top})
      : super(repaint: s._frame);
  final _VibeLayerState s;
  final bool dark;
  final double top;

  static final _leaf = Path()
    ..moveTo(-0.5, 0.1)
    ..cubicTo(-0.32, -0.55, 0.2, -0.62, 0.5, -0.5)
    ..cubicTo(0.36, 0.1, -0.08, 0.65, -0.5, 0.1)
    ..close();

  static final _petal = Path()
    ..moveTo(0, -0.5)
    ..quadraticBezierTo(0.5, -0.2, 0.12, 0.5)
    ..lineTo(0, 0.38)
    ..lineTo(-0.12, 0.5)
    ..quadraticBezierTo(-0.5, -0.2, 0, -0.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final vibe = s.widget.vibe;
    final t = s._t;
    final paint = Paint()..isAntiAlias = true;
    for (final p in s._ps) {
      switch (vibe) {
        case Vibe.autumn:
          canvas.save();
          canvas.translate(p.x, p.y);
          // Лёгкое «переворачивание» листа в полёте.
          canvas.scale(p.size, p.size * (0.55 + 0.45 * cos(t * 2 + p.phase)));
          canvas.rotate(p.rot);
          paint
            ..style = PaintingStyle.fill
            ..color = p.color.withValues(alpha: 0.55 + 0.4 * p.depth);
          canvas.drawPath(_leaf, paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.05
            ..color = Colors.black.withValues(alpha: 0.18);
          canvas.drawLine(
              const Offset(-0.42, 0.08), const Offset(0.44, -0.44), paint);
          canvas.restore();
        case Vibe.spring:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          canvas.scale(
              p.size * (0.6 + 0.4 * sin(t * 3 + p.phase).abs()), p.size);
          paint
            ..style = PaintingStyle.fill
            ..color = p.color.withValues(alpha: 0.6 + 0.35 * p.depth);
          canvas.drawPath(_petal, paint);
          canvas.restore();
        case Vibe.winter:
          paint
            ..style = PaintingStyle.fill
            ..maskFilter = null
            ..color = (dark ? Colors.white : const Color(0xFF9DBBE3))
                .withValues(alpha: 0.45 + 0.5 * p.depth);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
        case Vibe.summer:
          final pulse = 0.5 + 0.5 * sin(t * 2.2 + p.phase);
          final c = dark ? const Color(0xFFFFE27A) : const Color(0xFFF2A900);
          paint
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = c.withValues(alpha: 0.25 + 0.45 * pulse);
          canvas.drawCircle(Offset(p.x, p.y), p.size * 3.2, paint);
          paint
            ..maskFilter = null
            ..color = c.withValues(alpha: 0.6 + 0.4 * pulse);
          canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
        case Vibe.night:
          final tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 1.7 + p.phase * 3));
          final c = dark ? Colors.white : const Color(0xFF7C6CE0);
          paint
            ..style = PaintingStyle.fill
            ..maskFilter = null
            ..color = c.withValues(alpha: tw);
          if (p.size > 2.2) {
            // Крупные звёзды — четырёхлучевые искры.
            final r = p.size * 1.8 * tw;
            final o = Offset(p.x, p.y);
            canvas.drawPath(
                Path()
                  ..moveTo(o.dx, o.dy - r)
                  ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
                  ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
                  ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
                  ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
                  ..close(),
                paint);
          } else {
            canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
          }
        default:
          break;
      }
    }
    paint.maskFilter = null;
    if (vibe == Vibe.night && s._shootT >= 0) _shootingStar(canvas, size);
    if (vibe == Vibe.winter && !s.widget.compact) _garland(canvas, size, t);
  }

  void _shootingStar(Canvas canvas, Size size) {
    final k = s._shootT;
    final dir = const Offset(-1, 0.55);
    final head = s._shootFrom + dir * (size.width * 0.5 * k);
    final tail = head - dir * 90 * (1 - (k - 0.5).abs());
    final c = dark ? Colors.white : const Color(0xFF7C6CE0);
    final a = sin(pi * k);
    canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [
            c.withValues(alpha: 0),
            c.withValues(alpha: a),
          ]).createShader(Rect.fromPoints(tail, head)));
    canvas.drawCircle(head, 2.2, Paint()..color = c.withValues(alpha: a));
  }

  /// Новогодняя гирлянда: провод провисает дугами, лампочки мерцают.
  void _garland(Canvas canvas, Size size, double t) {
    const span = 130.0, sag = 16.0, step = 30.0;
    final y0 = top + 2;
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (dark ? Colors.white : const Color(0xFF2B3A30))
          .withValues(alpha: 0.35);
    final path = Path()..moveTo(0, y0);
    for (var x = 0.0; x < size.width + span; x += span) {
      path.quadraticBezierTo(x + span / 2, y0 + sag * 2, x + span, y0);
    }
    canvas.drawPath(path, wire);
    const colors = [
      Color(0xFFFF4D4D),
      Color(0xFFFFD23F),
      Color(0xFF3DDC84),
      Color(0xFF4DA6FF),
      Color(0xFFFF7AD9),
    ];
    var i = 0;
    for (final m in path.computeMetrics()) {
      for (var d = step / 2; d < m.length; d += step, i++) {
        final pos = m.getTangentForOffset(d)!.position;
        final c = colors[i % colors.length];
        final on = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.4 + i * 1.7));
        canvas.drawCircle(
            pos + const Offset(0, 5),
            9,
            Paint()
              ..color = c.withValues(alpha: 0.35 * on)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: pos + const Offset(0, 5), width: 6, height: 9),
                const Radius.circular(3)),
            Paint()..color = c.withValues(alpha: 0.55 + 0.45 * on));
        canvas.drawRect(
            Rect.fromCenter(
                center: pos + const Offset(0, 0.5), width: 4, height: 3),
            Paint()..color = const Color(0xFF2B3A30));
      }
    }
  }

  @override
  bool shouldRepaint(_VibePainter old) =>
      old.dark != dark || old.top != top || old.s != s;
}
