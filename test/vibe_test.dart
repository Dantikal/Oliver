import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oliver/core/storage/prefs.dart';
import 'package:oliver/core/theme/app_palette.dart';
import 'package:oliver/core/vibe/vibe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final vibe in Vibe.values) {
    for (final dark in [false, true]) {
      testWidgets('вайб ${vibe.name} (${dark ? 'тёмная' : 'светлая'})',
          (t) async {
        t.view.physicalSize = const Size(402 * 3, 874 * 3);
        t.view.devicePixelRatio = 3;
        SharedPreferences.setMockInitialValues({'vibe': vibe.name});
        final prefs = await SharedPreferences.getInstance();
        await t.pumpWidget(ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                extensions: [dark ? AppPalette.dark : AppPalette.light]),
            home: VibeOverlay(
              child: Scaffold(
                body: Center(
                    child: ElevatedButton(
                        onPressed: () {}, child: const Text('tap'))),
              ),
            ),
          ),
        ));
        // Несколько секунд анимации: частицы падают, перерождаются.
        for (var i = 0; i < 120; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        // Касание проходит сквозь слой частиц и вызывает «ветер».
        await t.tap(find.text('tap'));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(VibeLayer),
            vibe == Vibe.off ? findsNothing : findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
