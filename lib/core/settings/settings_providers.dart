import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs.dart';

/// Выбор темы: системная, светлая, тёмная или песочная (светлая по яркости).
enum AppThemeChoice {
  system,
  light,
  dark,
  sand;

  ThemeMode get mode => switch (this) {
        AppThemeChoice.system => ThemeMode.system,
        AppThemeChoice.dark => ThemeMode.dark,
        _ => ThemeMode.light,
      };
}

final themeChoiceProvider =
    NotifierProvider<ThemeChoiceNotifier, AppThemeChoice>(
        ThemeChoiceNotifier.new);

class ThemeChoiceNotifier extends Notifier<AppThemeChoice> {
  static const _key = 'theme_mode';

  @override
  AppThemeChoice build() {
    final v = ref.read(sharedPrefsProvider).getString(_key);
    return AppThemeChoice.values
        .firstWhere((m) => m.name == v, orElse: () => AppThemeChoice.system);
  }

  void set(AppThemeChoice choice) {
    state = choice;
    ref.read(sharedPrefsProvider).setString(_key, choice.name);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'locale';

  @override
  Locale build() =>
      Locale(ref.read(sharedPrefsProvider).getString(_key) ?? 'ru');

  void set(Locale locale) {
    state = locale;
    ref.read(sharedPrefsProvider).setString(_key, locale.languageCode);
  }
}

final viewModeGridProvider =
    NotifierProvider<BoolPref, bool>(() => BoolPref('view_grid', true));
final pushEnabledProvider =
    NotifierProvider<BoolPref, bool>(() => BoolPref('push_enabled', true));
final chatSoundProvider =
    NotifierProvider<BoolPref, bool>(() => BoolPref('chat_sound', true));
final uiSoundProvider =
    NotifierProvider<BoolPref, bool>(() => BoolPref('ui_sound', true));

class BoolPref extends Notifier<bool> {
  BoolPref(this.key, this.defaultValue);
  final String key;
  final bool defaultValue;

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(key) ?? defaultValue;

  void set(bool v) {
    state = v;
    ref.read(sharedPrefsProvider).setBool(key, v);
  }

  void toggle() => set(!state);
}
