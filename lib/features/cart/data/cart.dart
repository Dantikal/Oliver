import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/storage/prefs.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/domain/user.dart';
import '../../catalog/domain/product.dart';
import '../../chats/data/chat_repositories.dart';
import '../../chats/domain/chat.dart';
import '../../chats/presentation/chat_controllers.dart';

/// Позиция корзины: снимок товара + выбранные варианты + количество.
class CartItem {
  const CartItem({
    required this.productId,
    required this.title,
    required this.price,
    required this.currency,
    required this.seller,
    required this.selection,
    required this.qty,
    this.cover,
  });

  final String productId;
  final String title;
  final String? cover;
  final double price;
  final Currency currency;
  final User seller;

  /// Название группы → выбранное значение: {«Модель»: «iPhone 15»}.
  final Map<String, String> selection;
  final int qty;

  /// Одинаковый товар с разными вариантами — разные позиции.
  String get key =>
      '$productId|${selection.entries.map((e) => '${e.key}=${e.value}').join(';')}';

  double get total => price * qty;

  String get selectionText => selection.values.join(' · ');

  CartItem withQty(int q) => CartItem(
        productId: productId,
        title: title,
        cover: cover,
        price: price,
        currency: currency,
        seller: seller,
        selection: selection,
        qty: q,
      );

  factory CartItem.fromProduct(
          Product p, Map<String, String> selection, int qty) =>
      CartItem(
        productId: p.id.split('~').first,
        title: p.title,
        cover: p.coverUrl,
        price: p.price ?? 0,
        currency: p.currency,
        seller: p.seller,
        selection: selection,
        qty: qty,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'title': title,
        'cover': cover,
        'price': price,
        'currency': currency.api,
        'seller': {
          'id': seller.id,
          'fullName': seller.fullName,
          'avatarUrl': seller.avatarUrl,
        },
        'selection': selection,
        'qty': qty,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: j['productId'] as String,
        title: j['title'] as String,
        cover: j['cover'] as String?,
        price: (j['price'] as num).toDouble(),
        currency: Currency.fromApi(j['currency'] as String?),
        seller: User.fromJson(Map<String, dynamic>.from(j['seller'] as Map)),
        selection: Map<String, String>.from(j['selection'] as Map),
        qty: j['qty'] as int,
      );
}

/// Корзина живёт на устройстве; оформление — заказ продавцу в чат.
final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartCountProvider = Provider<int>(
    (ref) => ref.watch(cartProvider).fold(0, (s, i) => s + i.qty));

class CartNotifier extends Notifier<List<CartItem>> {
  static const _key = 'cart_items';

  @override
  List<CartItem> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          CartItem.fromJson(Map<String, dynamic>.from(e as Map))
      ];
    } catch (_) {
      return const [];
    }
  }

  void _save(List<CartItem> items) {
    state = items;
    ref
        .read(sharedPrefsProvider)
        .setString(_key, jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  void add(CartItem item) {
    final i = state.indexWhere((x) => x.key == item.key);
    if (i < 0) return _save([...state, item]);
    final next = [...state];
    next[i] = next[i].withQty((next[i].qty + item.qty).clamp(1, 99));
    _save(next);
  }

  void setQty(String key, int qty) {
    if (qty <= 0) return remove(key);
    _save([
      for (final i in state) i.key == key ? i.withQty(qty.clamp(1, 99)) : i
    ]);
  }

  void remove(String key) => _save(state.where((i) => i.key != key).toList());

  void removeSeller(String sellerId) =>
      _save(state.where((i) => i.seller.id != sellerId).toList());
}

/// Суммы по валютам: «2 400 сом + $35».
String cartTotalText(BuildContext c, Iterable<CartItem> items) {
  final byCur = <Currency, double>{};
  for (final i in items) {
    byCur[i.currency] = (byCur[i.currency] ?? 0) + i.total;
  }
  return byCur.entries.map((e) => formatPrice(c, e.value, e.key)).join(' + ');
}

/// Текст заказа для продавца.
String orderMessage(BuildContext c, List<CartItem> items) {
  final b = StringBuffer('${c.tr('orderHello')}\n');
  for (final i in items) {
    final sel = i.selection.isEmpty ? '' : ' (${i.selectionText})';
    b.writeln(
        '• ${i.title}$sel × ${i.qty} — ${formatPrice(c, i.total, i.currency)}');
  }
  b.write('${c.tr('orderTotal')}: ${cartTotalText(c, items)}');
  return b.toString();
}

/// Отправляет заказ продавцу сообщением и открывает чат.
Future<void> sendOrder(
    BuildContext context, WidgetRef ref, List<CartItem> items) async {
  final seller = items.first.seller;
  final text = orderMessage(context, items);
  final repo = ref.read(chatRepositoryProvider);
  final chatId = await repo.createOrGet(
      peerId: seller.id, productId: items.first.productId);
  await repo.send(chatId, type: MessageType.text, content: text);
  ref.read(chatListProvider.notifier).refresh().ignore();
  if (context.mounted) context.push('/chat/$chatId', extra: seller);
}
