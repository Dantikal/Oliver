import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_providers.dart';
import 'core/sound/sfx.dart';
import 'core/theme/app_theme.dart';
import 'core/vibe/vibe.dart';
import 'core/widgets/offline_banner.dart';
import 'features/chats/presentation/inbox.dart';

class OliverApp extends ConsumerWidget {
  const OliverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    // Входящие сообщения: звук и баннер, пока пользователь вошёл.
    ref.watch(inboxProvider);
    Sfx.ui = ref.watch(uiSoundProvider);
    Sfx.chat = ref.watch(chatSoundProvider);
    return MaterialApp.router(
      title: 'Oliver',
      debugShowCheckedModeBanner: false,
      theme: choice == AppThemeChoice.sand ? AppTheme.sand() : AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: choice.mode,
      locale: ref.watch(localeProvider),
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => VibeOverlay(
          child: OfflineBanner(child: child ?? const SizedBox.shrink())),
    );
  }
}
