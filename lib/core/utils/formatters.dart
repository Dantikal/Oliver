import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../features/catalog/domain/product.dart';
import '../l10n/app_strings.dart';

final _num = NumberFormat('#,##0', 'en');

String formatNumber(num v) => _num.format(v).replaceAll(',', ' ');

String formatPrice(BuildContext c, double? price, Currency currency) =>
    switch (currency) {
      Currency.negotiable => c.tr('negotiable'),
      Currency.free => c.tr('free'),
      Currency.usd => '\$${formatNumber(price ?? 0)}',
      Currency.kgs => '${formatNumber(price ?? 0)} ${c.tr('som')}',
    };

String two(int v) => v.toString().padLeft(2, '0');

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatClock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

/// 0:07, 1:23 — длительность голосового.
String formatVoiceDuration(int seconds) =>
    '${seconds ~/ 60}:${two(seconds % 60)}';

String formatChatTime(BuildContext c, DateTime d) {
  final now = DateTime.now();
  if (isSameDay(d, now)) return formatClock(d);
  if (isSameDay(d, now.subtract(const Duration(days: 1)))) {
    return c.tr('yesterday');
  }
  return '${two(d.day)}.${two(d.month)}';
}

String formatDayHeader(BuildContext c, DateTime d) {
  final now = DateTime.now();
  if (isSameDay(d, now)) return c.tr('today');
  if (isSameDay(d, now.subtract(const Duration(days: 1)))) {
    return c.tr('yesterday');
  }
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String timeAgo(BuildContext c, DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return c.tr('justNow');
  if (diff.inMinutes < 60) {
    return c.tr('minAgo').replaceAll('{n}', '${diff.inMinutes}');
  }
  if (diff.inHours < 24) {
    return c.tr('hAgo').replaceAll('{n}', '${diff.inHours}');
  }
  if (diff.inDays < 7) return c.tr('dAgo').replaceAll('{n}', '${diff.inDays}');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}
