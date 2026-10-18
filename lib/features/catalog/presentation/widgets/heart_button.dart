import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/glass.dart';
import '../../../favorites/presentation/favorites_controller.dart';

class HeartButton extends ConsumerStatefulWidget {
  const HeartButton(
      {super.key, required this.productId, this.size = 36, this.glass = true});

  final String productId;
  final double size;
  final bool glass;

  @override
  ConsumerState<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends ConsumerState<HeartButton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final _scale = TweenSequence([
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.88), weight: 30),
    TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    _c.forward(from: 0);
    try {
      await ref.read(favoriteIdsProvider.notifier).toggle(widget.productId);
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.productId.split('~').first;
    final fav = ref.watch(favoriteIdsProvider.select((s) => s.contains(base)));
    final p = context.palette;
    final icon = ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(fav),
          size: widget.size * 0.5,
          color:
              fav ? AppColors.danger : (widget.glass ? Colors.white : p.text),
        ),
      ),
    );
    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.glass
            ? PhotoGlass(padding: EdgeInsets.zero, child: Center(child: icon))
            : DecoratedBox(
                decoration:
                    BoxDecoration(color: p.surface2, shape: BoxShape.circle),
                child: Center(child: icon)),
      ),
    );
  }
}
