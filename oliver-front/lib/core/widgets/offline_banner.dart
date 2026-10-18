import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../network/connectivity_provider.dart';

/// Баннер «нет соединения» поверх всего приложения.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          top: online ? -(top + 60) : 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, top + 6, 16, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFF3B5C), Color(0xFFFF8A3D)]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('offline'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
