import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oliver/core/storage/prefs.dart';
import 'package:oliver/core/theme/app_palette.dart';
import 'package:oliver/features/auth/domain/user.dart';
import 'package:oliver/features/cart/data/cart.dart';
import 'package:oliver/features/cart/presentation/variant_sheet.dart';
import 'package:oliver/features/catalog/domain/product.dart';
import 'package:oliver/features/seller/presentation/options_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _case = Product(
  id: 'p1',
  title: 'Чехлы для iPhone, силикон MagSafe',
  description: 'd',
  price: 1200,
  currency: Currency.kgs,
  categoryId: 'c1-1',
  categoryName: 'Телефоны',
  regionId: 'r0',
  regionName: 'Бишкек',
  cityId: 'ct0',
  cityName: 'Бишкек',
  media: const [],
  seller: const User(id: 'u2', fullName: 'Продавец'),
  createdAt: DateTime(2026),
  options: const [
    ProductOption(name: 'Модель', values: [
      OptionValue(label: 'iPhone 13'),
      OptionValue(label: 'iPhone 15 Pro Max'),
    ]),
    ProductOption(name: 'Цвет', kind: OptionKind.color, values: [
      OptionValue(label: 'Чёрный', color: '#1C1C1E'),
      OptionValue(label: 'Розовый', color: '#F49AC1'),
    ]),
  ],
);

Widget _app(SharedPreferences prefs, Widget child) => ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('выбор вариантов → в корзину', (t) async {
    t.view.physicalSize = const Size(402 * 3, 874 * 3);
    t.view.devicePixelRatio = 3;
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef r;
    await t.pumpWidget(_app(
      prefs,
      Consumer(builder: (context, ref, _) {
        r = ref;
        return Center(
          child: ElevatedButton(
            onPressed: () => openBuyFlow(context, ref, _case, buyNow: false),
            child: const Text('go'),
          ),
        );
      }),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('iPhone 15 Pro Max'), findsOneWidget);
    // Пока не выбрано всё — подсказка, что выбрать.
    expect(find.textContaining('модель, цвет'), findsOneWidget);
    await t.tap(find.text('iPhone 15 Pro Max'));
    await t.tap(find.byTooltip('Розовый'));
    await t.pump(const Duration(milliseconds: 700));
    await t.tap(find.byIcon(Icons.add_rounded).last);
    await t.pump(const Duration(milliseconds: 700));
    await t.tap(find.textContaining('В корзину'));
    await t.pump(const Duration(milliseconds: 700));
    final items = r.read(cartProvider);
    expect(items, hasLength(1));
    expect(items.single.selection,
        {'Модель': 'iPhone 15 Pro Max', 'Цвет': 'Розовый'});
    expect(items.single.qty, 2);
  });

  testWidgets('редактор вариантов рисуется без переполнений', (t) async {
    t.view.physicalSize = const Size(402 * 3, 874 * 3);
    t.view.devicePixelRatio = 3;
    final prefs = await SharedPreferences.getInstance();
    var opts = _case.options;
    await t.pumpWidget(_app(
      prefs,
      SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: OptionsEditor(options: opts, onChanged: (o) => opts = o),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Модель · 2'), findsOneWidget);
    await t.tap(find.byTooltip('Белый'));
    await t.pumpAndSettle();
    expect(opts[1].values.map((v) => v.label), contains('Белый'));
  });
}
