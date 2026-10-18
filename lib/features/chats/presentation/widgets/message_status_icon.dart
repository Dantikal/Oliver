import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/chat.dart';

/// Статусы: отправляется (часики) / отправлено ✓ / доставлено ✓✓ / прочитано ✓✓ (цветные) / ошибка.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon(
      {super.key, required this.status, this.size = 15, this.onBubble = false});
  final MessageStatus status;
  final double size;
  final bool onBubble;

  @override
  Widget build(BuildContext context) {
    final base = onBubble
        ? Colors.white.withValues(alpha: 0.75)
        : context.palette.textTertiary;
    final (icon, color) = switch (status) {
      MessageStatus.sending => (Icons.schedule_rounded, base),
      MessageStatus.sent => (Icons.done_rounded, base),
      MessageStatus.delivered => (Icons.done_all_rounded, base),
      MessageStatus.read => (
          Icons.done_all_rounded,
          onBubble ? AppColors.lime : AppColors.primary
        ),
      MessageStatus.failed => (Icons.error_rounded, AppColors.danger),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Icon(icon, key: ValueKey(status), size: size, color: color),
    );
  }
}
