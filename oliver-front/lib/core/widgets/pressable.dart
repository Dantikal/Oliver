import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../sound/sfx.dart';

/// Мягкое «нажатие»: быстрое сжатие и пружинный отскок с лёгким перелётом.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key,
      required this.child,
      this.onTap,
      this.onLongPress,
      this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  // 0 — отпущено, 1 — нажато; пружина может уйти чуть ниже нуля (перелёт).
  late final _c = AnimationController.unbounded(vsync: this);
  static const _spring =
      SpringDescription(mass: 1, stiffness: 520, damping: 18);

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _down() {
    if (!_enabled) return;
    _c.animateTo(1,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOut);
  }

  void _up() {
    if (!_enabled) return;
    _c.animateWith(SpringSimulation(_spring, _c.value, 0, -4));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _down(),
      onTapUp: (_) => _up(),
      onTapCancel: _up,
      onTap: widget.onTap == null
          ? null
          : () {
              Sfx.tap();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.scale(
          scale: 1 - (1 - widget.scale) * _c.value,
          child: child,
        ),
      ),
    );
  }
}
