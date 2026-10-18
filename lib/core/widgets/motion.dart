import 'package:flutter/material.dart';

/// Общие кривые/длительности, чтобы всё двигалось в одном ритме.
class Motion {
  Motion._();

  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 620);

  /// «Экспоненциальный» выход — быстро стартует, долго мягко доезжает.
  static const ease = Cubic(0.16, 1, 0.3, 1);
  static const spring = Curves.easeOutBack;
}

/// Появление снизу с проявлением. [index] даёт каскадную задержку.
/// Проигрывается один раз за жизнь элемента.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 45),
    this.maxDelaySteps = 8,
    this.offset = 26,
    this.duration = const Duration(milliseconds: 700),
  });

  final Widget child;
  final int index;
  final Duration step;
  final int maxDelaySteps;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _a = CurvedAnimation(parent: _c, curve: Motion.ease);

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxDelaySteps);
    Future.delayed(widget.step * steps, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _a.value)),
          child: Transform.scale(scale: 0.95 + 0.05 * _a.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Бесконечное мягкое «дыхание»: значение 0..1..0 передаётся в [builder].
class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.builder,
    this.period = const Duration(milliseconds: 1600),
    this.child,
  });

  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration period;
  final Widget? child;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period)
    ..repeat(reverse: true);
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeInOutSine);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => widget.builder(context, _a.value, child),
        child: widget.child,
      );
}

/// Контейнер вкладок для StatefulShellRoute: держит все ветки живыми
/// (как IndexedStack), но переключает их плавным fade + лёгким сдвигом.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer(
      {super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: Motion.normal, value: 1);
  late final _a = CurvedAnimation(parent: _c, curve: Motion.ease);
  late int _prev = widget.currentIndex;

  @override
  void didUpdateWidget(AnimatedBranchContainer old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _prev = old.currentIndex;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.currentIndex;
    final dir = cur >= _prev ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _branch(i, cur, t, dir),
          ],
        );
      },
    );
  }

  Widget _branch(int i, int cur, double t, double dir) {
    final active = i == cur;
    final leaving = i == _prev && t < 1 && _prev != cur;
    final visible = active || leaving;
    // Fade-through: старая вкладка гаснет с лёгким отъездом назад,
    // новая проявляется после неё, «наплывая» из глубины.
    double opacity = 0;
    double dx = 0;
    double scale = 1;
    if (active) {
      final k = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      opacity = k;
      scale = 0.94 + 0.06 * k;
      dx = 18 * dir * (1 - k);
    } else if (leaving) {
      final k = (t / 0.35).clamp(0.0, 1.0);
      opacity = 1 - k;
      scale = 1 - 0.03 * k;
      dx = -10 * dir * k;
    }
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: active,
        child: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Transform.scale(scale: scale, child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Число «набегает» от 0 до значения. Нечисловые строки показываются как есть.
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, this.style});
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(value.replaceAll(RegExp(r'\s'), ''));
    if (n == null) return Text(value, style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: n.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

/// Оборачивает элементы колонки в каскадное появление (отступы не трогает).
List<Widget> staggered(List<Widget> children, {int startIndex = 0}) {
  var i = startIndex;
  return [
    for (final c in children)
      c is SizedBox && c.child == null ? c : FadeSlideIn(index: i++, child: c),
  ];
}

/// Шапка с параллаксом при прокрутке и «растяжением» при оттягивании вниз.
/// Кладётся первым элементом в прокручиваемый список.
class ParallaxHeader extends StatefulWidget {
  const ParallaxHeader({super.key, required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  State<ParallaxHeader> createState() => _ParallaxHeaderState();
}

class _ParallaxHeaderState extends State<ParallaxHeader> {
  ScrollPosition? _pos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pos?.removeListener(_tick);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_tick);
  }

  void _tick() => setState(() {});

  @override
  void dispose() {
    _pos?.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final px = _pos?.hasPixels == true ? _pos!.pixels : 0.0;
    final over = px < 0 ? -px : 0.0;
    return SizedBox(
      height: widget.height,
      child: Transform.translate(
        offset: Offset(0, px < 0 ? px : px * 0.45),
        child: Transform.scale(
          alignment: Alignment.bottomCenter,
          scale: 1 + over / widget.height,
          child: widget.child,
        ),
      ),
    );
  }
}
