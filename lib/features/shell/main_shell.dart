import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/sound/sfx.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/pressable.dart';
import '../favorites/presentation/favorites_controller.dart';
import '../notifications/presentation/counters_controller.dart';

/// Отступ снизу у прокручиваемого контента под плавающую навигацию.
const double kNavBarSpace = 120;

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) {
    HapticFeedback.selectionClick();
    Sfx.tap();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsBadge = ref.watch(countersProvider.select((c) => c.chatsBadge));
    final favCount = ref.watch(favoritesCountProvider);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: _GlassNavBar(
        index: shell.currentIndex,
        onTap: _go,
        onCreate: () {
          HapticFeedback.mediumImpact();
          context.push('/create');
        },
        items: [
          _NavItem(
              Icons.home_outlined, Icons.home_rounded, context.tr('navHome')),
          _NavItem(Icons.favorite_border_rounded, Icons.favorite_rounded,
              context.tr('navFavorites'),
              badge: favCount, dot: true),
          _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded,
              context.tr('navChats'),
              badge: chatsBadge),
          _NavItem(Icons.person_outline_rounded, Icons.person_rounded,
              context.tr('navProfile')),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label,
      {this.badge = 0, this.dot = false});
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  final bool dot;
}

class _GlassNavBar extends StatefulWidget {
  const _GlassNavBar(
      {required this.index,
      required this.onTap,
      required this.onCreate,
      required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;
  final List<_NavItem> items;

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560), value: 1);
  late int _from = widget.index;

  @override
  void didUpdateWidget(_GlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Колонка ячейки: 0,1 слева, 3,4 справа, 2 — кнопка «создать».
  static int _slot(int i) => i < 2 ? i : i + 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = context.isDark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pillColor = dark ? AppColors.lime : AppColors.ink;
    final activeFg = dark ? AppColors.ink : AppColors.lime;

    Widget item(int i) {
      final it = widget.items[i];
      final active = i == widget.index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTap(i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: active ? 1.08 : 1,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (c, a) => ScaleTransition(
                          scale: Tween(begin: 0.6, end: 1.0).animate(
                              CurvedAnimation(
                                  parent: a, curve: Curves.easeOutBack)),
                          child: FadeTransition(opacity: a, child: c)),
                      child: Icon(
                        active ? it.activeIcon : it.icon,
                        key: ValueKey(active),
                        size: 23,
                        color: active ? activeFg : p.textTertiary,
                      ),
                    ),
                  ),
                  if (it.badge > 0 && !it.dot)
                    Positioned(
                        top: -7,
                        right: -10,
                        child: CountBadge(count: it.badge, small: true)),
                ],
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: context.text.labelSmall!.copyWith(
                  fontSize: 10,
                  color: active
                      ? (dark ? AppColors.ink : Colors.white)
                      : p.textTertiary,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(it.label,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom - 6 : 12),
      child: Glass(
        radius: 34,
        blur: 30,
        // Плотнее обычного стекла: подписи читаются поверх любых фото.
        tint: p.surface.withValues(alpha: dark ? 0.78 : 0.86),
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(builder: (context, c) {
            final cell = c.maxWidth / 5;
            return Stack(
              children: [
                // «Жидкий» индикатор: едет с перелётом и тянется в пути.
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final t = _c.value;
                    final move = Curves.easeOutBack.transform(t);
                    final from = _slot(_from) * cell;
                    final to = _slot(widget.index) * cell;
                    final stretch = sin(pi * t) * 0.45;
                    final w = (cell - 10) * (1 + stretch);
                    final x = from + (to - from) * move + (cell - w) / 2;
                    return Positioned(
                      left: x,
                      top: 7,
                      bottom: 7,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: AppRadius.pillAll,
                          boxShadow: AppShadows.glow(
                              dark ? AppColors.lime : AppColors.ink,
                              strength: 0.6),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    item(0),
                    item(1),
                    Expanded(
                        child: Center(
                            child: _CreateButton(onTap: widget.onCreate))),
                    item(2),
                    item(3),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Лаймовая кнопка «создать»: дышащее свечение, поворот плюса при нажатии.
class _CreateButton extends StatefulWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        setState(() => _turns += 0.25);
        widget.onTap();
      },
      scale: 0.86,
      child: Breathing(
        period: const Duration(milliseconds: 2000),
        builder: (_, t, child) => Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.limeGradient,
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.35 + 0.3 * t),
                  blurRadius: 10 + 14 * t,
                  spreadRadius: -2),
            ],
          ),
          child: child,
        ),
        child: AnimatedRotation(
          turns: _turns,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.add_rounded, color: AppColors.ink, size: 30),
        ),
      ),
    );
  }
}
