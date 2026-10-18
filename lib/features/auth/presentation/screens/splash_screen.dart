import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/animated_blobs.dart';
import '../../../../core/widgets/oliver_logo.dart';

/// Длительность входной анимации (под неё подогнан assets/sounds/intro.wav).
const kIntroDuration = Duration(milliseconds: 2200);

/// Плеер живёт дольше экрана, чтобы звук не обрывался при переходе.
final _introPlayer = AudioPlayer();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: kIntroDuration);

  Animation<double> _seg(double a, double b, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  late final _box = _seg(0.0, 0.22, Curves.easeOutBack);
  late final _ring = _seg(0.08, 0.42, Curves.easeInOutCubic);
  late final _leaf = _seg(0.40, 0.72, Curves.elasticOut);
  late final _burst = _seg(0.40, 0.80, Curves.easeOutCubic);
  late final _word = _seg(0.55, 0.85, Curves.easeOutCubic);
  late final _tag = _seg(0.72, 1.0, Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _c.forward();
    _playSound();
    Future.delayed(const Duration(milliseconds: 880), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  Future<void> _playSound() async {
    try {
      // Уважаем беззвучный режим iOS и не глушим чужую музыку.
      await _introPlayer
          .setAudioContext(AudioContextConfig(respectSilence: true).build());
      await _introPlayer.play(AssetSource('sounds/intro.wav'), volume: 0.7);
    } catch (_) {
      // Звук — украшение, без него ничего не ломается.
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
              child: Hero(tag: 'auth-bg', child: AnimatedBlobs())),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final box = _box.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: size * 2.2,
                      height: size * 2.2,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ореол: распускается вместе с кольцом и мягко гаснет.
                          Opacity(
                            opacity: (_ring.value * (1 - 0.5 * _tag.value))
                                .clamp(0.0, 1.0),
                            child: Container(
                              width: size * (1.2 + 0.9 * _ring.value),
                              height: size * (1.2 + 0.9 * _ring.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  AppColors.lime.withValues(alpha: 0.55),
                                  AppColors.primary.withValues(alpha: 0.18),
                                  AppColors.primary.withValues(alpha: 0),
                                ], stops: const [
                                  0,
                                  0.45,
                                  1
                                ]),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: const Size.square(size * 2.2),
                            painter: _BurstPainter(_burst.value),
                          ),
                          Opacity(
                            opacity: box.clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: (1 - box) * -0.25,
                              child: Transform.scale(
                                scale: 0.5 + 0.5 * box,
                                child: Hero(
                                  tag: 'auth-logo',
                                  child: SizedBox.square(
                                    dimension: size,
                                    child: CustomPaint(
                                      painter: OliverMarkPainter(
                                        ring: _ring.value,
                                        leaf: _leaf.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Слово проявляется из размытия, чуть «приземляясь».
                    Opacity(
                      opacity: _word.value,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                            sigmaX: 10 * (1 - _word.value),
                            sigmaY: 10 * (1 - _word.value)),
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - _word.value)),
                          child: Transform.scale(
                            scale: 1.12 - 0.12 * _word.value,
                            child: const OliverWordmark(fontSize: 46),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _tag.value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - _tag.value)),
                        child: Text(context.tr('tagline'),
                            style: context.text.bodyMedium?.copyWith(
                                color: context.palette.textSecondary,
                                letterSpacing: 0.4 + 2 * (1 - _tag.value))),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Искры разлетаются, когда появляется листик: светящаяся точка + хвостик.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    const n = 10;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * 2 * pi / n + 0.3;
      final dist = size.width * (0.26 + 0.22 * t) * (i.isEven ? 1 : 0.82);
      final r = (i.isEven ? 4.5 : 3.0) * fade + 0.5;
      final dir = Offset(cos(a), sin(a));
      final pos = c + dir * dist;
      final color = LeafSeason
          .current.sparkColors[i % LeafSeason.current.sparkColors.length];
      // Хвост к центру.
      canvas.drawLine(
        pos - dir * (18 * fade),
        pos,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 1.2
          ..shader = LinearGradient(colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: fade),
          ]).createShader(Rect.fromPoints(pos - dir * (18 * fade), pos)),
      );
      // Свечение и ядро.
      canvas.drawCircle(
          pos,
          r * 2.6,
          Paint()
            ..color = color.withValues(alpha: 0.35 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(pos, r, Paint()..color = color.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
