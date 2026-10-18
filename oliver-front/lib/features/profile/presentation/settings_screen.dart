import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/picker_sheet.dart';
import '../../../core/widgets/pressable.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/vibe/vibe.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _languages = {
    'ru': 'Русский',
    'ky': 'Кыргызча',
    'en': 'English'
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeChoiceProvider);
    final push = ref.watch(pushEnabledProvider);
    final sound = ref.watch(chatSoundProvider);
    final uiSound = ref.watch(uiSoundProvider);
    final vibe = ref.watch(vibeProvider);

    Future<void> pickLanguage() async {
      final code = await showPickerSheet<String>(
        context,
        title: context.tr('language'),
        items: _languages.keys.toList(),
        labelOf: (c) => _languages[c]!,
        leading: (c) => Text(c.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w800)),
        isSelected: (c) => c == locale.languageCode,
      );
      if (code != null) ref.read(localeProvider.notifier).set(Locale(code));
    }

    Future<void> logout() async {
      final ok = await showConfirmDialog(
        context,
        title: context.tr('logoutQ'),
        message: context.tr('logoutSub'),
        confirm: context.tr('logout'),
        destructive: true,
        icon: Icons.logout_rounded,
      );
      if (ok) await ref.read(authControllerProvider.notifier).logout();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop()),
        title: Text(context.tr('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Group(title: context.tr('notifications'), children: [
            _Tile(
              icon: Icons.notifications_active_rounded,
              color: AppColors.leaf,
              title: context.tr('pushNotifications'),
              subtitle: context.tr('pushSub'),
              trailing: Switch(
                  value: push,
                  onChanged: ref.read(pushEnabledProvider.notifier).set),
            ),
            _Tile(
              icon: Icons.volume_up_rounded,
              color: AppColors.mint,
              title: context.tr('chatSounds'),
              trailing: Switch(
                  value: sound,
                  onChanged: ref.read(chatSoundProvider.notifier).set),
            ),
            _Tile(
              icon: Icons.touch_app_rounded,
              color: AppColors.teal,
              title: context.tr('uiSounds'),
              subtitle: context.tr('uiSoundsSub'),
              trailing: Switch(
                  value: uiSound,
                  onChanged: ref.read(uiSoundProvider.notifier).set),
            ),
          ]),
          _Group(title: context.tr('appearance'), children: [
            _Tile(
              icon: Icons.translate_rounded,
              color: AppColors.primary,
              title: context.tr('language'),
              onTap: pickLanguage,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_languages[locale.languageCode]!,
                      style: context.text.labelMedium
                          ?.copyWith(color: p.textSecondary)),
                  Icon(Icons.chevron_right_rounded, color: p.textTertiary),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const _IconBox(
                        icon: Icons.dark_mode_rounded, color: AppColors.forest),
                    const SizedBox(width: 14),
                    Text(context.tr('theme'),
                        style:
                            context.text.titleSmall?.copyWith(fontSize: 15.5)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (i, c) in AppThemeChoice.values.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _ThemeTile(
                            choice: c,
                            selected: c == mode,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(themeChoiceProvider.notifier).set(c);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const _IconBox(
                        icon: Icons.auto_awesome_rounded,
                        color: Color(0xFFE9A23B)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.tr('vibe'),
                              style: context.text.titleSmall
                                  ?.copyWith(fontSize: 15.5)),
                          Text(context.tr('vibeSub'),
                              style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: Vibe.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final v = Vibe.values[i];
                        return _VibeTile(
                          vibe: v,
                          selected: v == vibe,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(vibeProvider.notifier).set(v);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]),
          _Group(title: context.tr('about'), children: [
            _Tile(
              icon: Icons.info_rounded,
              color: AppColors.teal,
              title: context.tr('version'),
              trailing: Text('1.0.0${AppConfig.useMock ? ' · mock' : ''}',
                  style: context.text.labelMedium
                      ?.copyWith(color: p.textSecondary)),
            ),
            _Tile(
              icon: Icons.shield_rounded,
              color: AppColors.success,
              title: context.tr('privacy'),
              onTap: () => context.showSnack(context.tr('soon')),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ),
          ]),
          const SizedBox(height: 8),
          Material(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: logout,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Text(context.tr('logout'),
                        style: context.text.labelLarge
                            ?.copyWith(color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(title.toUpperCase(),
                style: context.text.labelSmall
                    ?.copyWith(color: p.textTertiary, letterSpacing: 1.1)),
          ),
          Container(
            decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: p.border)),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: AppRadius.mdAll),
        child: Icon(icon, color: color, size: 20),
      );
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon,
      required this.color,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mdAll,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.text.titleSmall?.copyWith(fontSize: 15.5)),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Плитка темы: мини-превью фона, текста и акцента.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile(
      {required this.choice, required this.selected, required this.onTap});
  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget swatch(AppPalette pal) => Container(
          color: pal.bg,
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 6,
                  width: 26,
                  decoration: BoxDecoration(
                      color: pal.text, borderRadius: AppRadius.pillAll)),
              const SizedBox(height: 4),
              Container(
                  height: 4,
                  width: 18,
                  decoration: BoxDecoration(
                      color: pal.textTertiary,
                      borderRadius: AppRadius.pillAll)),
              const Spacer(),
              Row(children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: AppColors.lime, shape: BoxShape.circle)),
              ]),
            ],
          ),
        );
    final preview = switch (choice) {
      AppThemeChoice.light => swatch(AppPalette.light),
      AppThemeChoice.dark => swatch(AppPalette.dark),
      AppThemeChoice.sand => swatch(AppPalette.sand),
      // Системная — светлая и тёмная, разделённые по диагонали.
      AppThemeChoice.system => Stack(fit: StackFit.expand, children: [
          swatch(AppPalette.light),
          ClipPath(clipper: _DiagonalClipper(), child: swatch(AppPalette.dark)),
        ]),
    };
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 66,
            padding: EdgeInsets.all(selected ? 3 : 0),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                  color: selected ? AppColors.lime : p.border,
                  width: selected ? 3 : 1),
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    selected ? AppRadius.lg - 5 : AppRadius.lg - 1),
                child: preview),
          ),
          const SizedBox(height: 6),
          Text(context.tr('theme_${choice.name}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                  color: selected ? p.text : p.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_DiagonalClipper oldClipper) => false;
}

/// Плитка вайба с живым превью частиц.
class _VibeTile extends StatelessWidget {
  const _VibeTile(
      {required this.vibe, required this.selected, required this.onTap});
  final Vibe vibe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = vibe.resolved;
    final colors = vibe.aurora;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 84,
              padding: EdgeInsets.all(selected ? 3 : 0),
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                    color: selected ? AppColors.lime : p.border,
                    width: selected ? 3 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    selected ? AppRadius.lg - 5 : AppRadius.lg - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: r == Vibe.off
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors[0].withValues(alpha: 0.55),
                                  colors[2].withValues(alpha: 0.35),
                                ],
                              ),
                        color: r == Vibe.off ? p.surface2 : null,
                      ),
                    ),
                    if (r != Vibe.off) VibeLayer(vibe: r, compact: true),
                    if (vibe == Vibe.off || vibe == Vibe.auto)
                      Center(
                        child: Icon(
                            vibe == Vibe.off
                                ? Icons.block_rounded
                                : Icons.auto_awesome_rounded,
                            color: vibe == Vibe.off
                                ? p.textTertiary
                                : Colors.white,
                            size: 26),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(context.tr(vibe.l10nKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                    color: selected ? p.text : p.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
