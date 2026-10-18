import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/animated_blobs.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/motion.dart';
import '../../../../core/widgets/oliver_logo.dart';
import '../../../../core/theme/app_colors.dart';

export '../../../../core/widgets/oliver_logo.dart';

/// Общий каркас экранов авторизации: Hero-фон + Hero-логотип + стеклянная карточка.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.logoSize = 64,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Hero(tag: 'auth-bg', child: AnimatedBlobs()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minHeight:
                          (c.maxHeight - 32).clamp(0.0, double.infinity)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 48,
                        child: showBack
                            ? IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                style: IconButton.styleFrom(
                                    backgroundColor:
                                        p.surface.withValues(alpha: 0.7)),
                                icon: Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 18, color: p.text),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Hero(tag: 'auth-logo', child: OliverLogo(size: logoSize)),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                          child: Text(title, style: context.text.displaySmall)),
                      const SizedBox(height: 8),
                      FadeSlideIn(
                        index: 1,
                        child: Text(subtitle,
                            style: context.text.bodyLarge
                                ?.copyWith(color: p.textSecondary)),
                      ),
                      const SizedBox(height: 26),
                      FadeSlideIn(
                        index: 2,
                        offset: 40,
                        child: Glass(
                          radius: AppRadius.xl,
                          blur: 28,
                          tint: p.surface
                              .withValues(alpha: context.isDark ? 0.62 : 0.72),
                          padding: const EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
