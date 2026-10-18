import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';

/// Подсказка в поиске, которая сама меняется: «Например: Toyota Camry».
class RotatingSearchHint extends StatefulWidget {
  const RotatingSearchHint({super.key, this.style});
  final TextStyle? style;

  @override
  State<RotatingSearchHint> createState() => _RotatingSearchHintState();
}

class _RotatingSearchHintState extends State<RotatingSearchHint> {
  int _i = Random().nextInt(6);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hints = context.tr('searchHints').split('|');
    final hint = hints[_i % hints.length];
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (cur, prev) => Stack(
            alignment: Alignment.centerLeft,
            children: [...prev, if (cur != null) cur]),
        transitionBuilder: (c, a) {
          final incoming = c.key == ValueKey(hint);
          return SlideTransition(
            position:
                Tween(begin: Offset(0, incoming ? 0.8 : -0.8), end: Offset.zero)
                    .animate(a),
            child: FadeTransition(opacity: a, child: c),
          );
        },
        child: Text('«$hint»',
            key: ValueKey(hint),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style),
      ),
    );
  }
}
