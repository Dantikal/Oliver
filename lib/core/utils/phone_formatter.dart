import 'package:flutter/services.dart';

/// Маска `XXX XXX XXX` для номера после префикса +996.
class KgPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) b.write(' ');
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  static String digitsOf(String formatted) =>
      formatted.replaceAll(RegExp(r'\D'), '');

  /// "+996700123456" → "700 123 456"
  static String fromFull(String? phone) {
    if (phone == null) return '';
    var d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('996')) d = d.substring(3);
    return KgPhoneFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: d))
        .text;
  }

  static String toFull(String formatted) => '+996${digitsOf(formatted)}';
}
