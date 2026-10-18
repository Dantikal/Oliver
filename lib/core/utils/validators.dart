import 'package:flutter/widgets.dart';

import '../l10n/app_strings.dart';
import 'phone_formatter.dart';

typedef Validator = String? Function(String?);

class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static Validator required(BuildContext c) =>
      (v) => (v == null || v.trim().isEmpty) ? c.tr('vRequired') : null;

  static Validator email(BuildContext c) => (v) {
        if (v == null || v.trim().isEmpty) return c.tr('vRequired');
        return _email.hasMatch(v.trim()) ? null : c.tr('vEmail');
      };

  /// Для входа — только длина.
  static Validator passwordLogin(BuildContext c) => (v) {
        if (v == null || v.isEmpty) return c.tr('vRequired');
        return v.length < 8 ? c.tr('vPasswordMin') : null;
      };

  /// Для регистрации: мин. 8 символов, заглавная буква и цифра.
  static Validator passwordStrong(BuildContext c) => (v) {
        if (v == null || v.isEmpty) return c.tr('vRequired');
        if (v.length < 8) return c.tr('vPasswordMin');
        if (!RegExp(r'[A-ZА-ЯЁ]').hasMatch(v)) return c.tr('vPasswordUpper');
        if (!RegExp(r'\d').hasMatch(v)) return c.tr('vPasswordDigit');
        return null;
      };

  static Validator confirm(BuildContext c, String Function() other) => (v) {
        if (v == null || v.isEmpty) return c.tr('vRequired');
        return v == other() ? null : c.tr('vPasswordMatch');
      };

  static Validator phone(BuildContext c) => (v) {
        final d = KgPhoneFormatter.digitsOf(v ?? '');
        if (d.isEmpty) return c.tr('vRequired');
        return d.length == 9 ? null : c.tr('vPhone');
      };

  static Validator fullName(BuildContext c) => (v) {
        if (v == null || v.trim().isEmpty) return c.tr('vRequired');
        return v.trim().length < 3 ? c.tr('vName') : null;
      };

  static Validator optionalUrl(BuildContext c, List<String> prefixes) => (v) {
        if (v == null || v.trim().isEmpty) return null;
        final t = v.trim();
        return prefixes.any(t.startsWith) ? null : c.tr('vLink');
      };
}
