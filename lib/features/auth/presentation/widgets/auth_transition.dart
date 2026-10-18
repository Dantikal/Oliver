import 'package:flutter/material.dart';

/// Page для go_router, создающий PageRouteBuilder с кастомной анимацией
/// (слайд + fade + scale, 380 мс, Curves.easeInOutCubic). Hero-элементы
/// (логотип и фон) перелетают между экранами входа и регистрации.
class AuthTransitionPage<T> extends Page<T> {
  const AuthTransitionPage({required this.child, super.key, super.name});

  final Widget child;

  static const duration = Duration(milliseconds: 380);

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (context, animation, secondary, child) {
        final inCurve =
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        final outCurve =
            CurvedAnimation(parent: secondary, curve: Curves.easeInOutCubic);
        // Входящий экран: выезжает справа, проявляется и «дорастает» до 1.0
        final incoming = SlideTransition(
          position: Tween(begin: const Offset(0.25, 0), end: Offset.zero)
              .animate(inCurve),
          child: FadeTransition(
            opacity: inCurve,
            child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(inCurve),
                child: child),
          ),
        );
        // Уходящий экран: смещается влево, слегка уменьшается и гаснет.
        return SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.12, 0))
              .animate(outCurve),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.0).animate(outCurve),
            child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 0.94).animate(outCurve),
                child: incoming),
          ),
        );
      },
    );
  }
}
