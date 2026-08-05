import 'package:flutter/services.dart';

/// Strip grouping separators and normalize Persian/Arabic digits to ASCII.
String digitsOnly(String input) {
  const Map<String, String> digitMap = <String, String>{
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  final StringBuffer buffer = StringBuffer();
  for (final int code in input.runes) {
    final String ch = String.fromCharCode(code);
    if (digitMap.containsKey(ch)) {
      buffer.write(digitMap[ch]);
    } else if (RegExp(r'[0-9]').hasMatch(ch)) {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Groups digits in threes from the right: `1234567` → `1,234,567`.
String formatGroupedDigits(String digits) {
  if (digits.isEmpty) return '';
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

/// Format a numeric value (or numeric string) with thousand separators.
/// Returns [fallback] for null/empty/non-numeric values like `---` / `—`.
String formatGroupedNumber(
  dynamic value, {
  String fallback = '---',
}) {
  if (value == null) return fallback;
  if (value is num) {
    final bool negative = value < 0;
    final String absInt = value.abs().truncate().toString();
    final String grouped = formatGroupedDigits(absInt);
    if (value is double && value != value.truncateToDouble()) {
      final String frac = value
          .toStringAsFixed(2)
          .split('.')
          .last
          .replaceFirst(RegExp(r'0+$'), '');
      final String withFrac = frac.isEmpty ? grouped : '$grouped.$frac';
      return negative ? '-$withFrac' : withFrac;
    }
    return negative ? '-$grouped' : grouped;
  }

  final String raw = value.toString().trim();
  if (raw.isEmpty ||
      raw == '---' ||
      raw == '—' ||
      raw.toLowerCase() == 'null') {
    return fallback;
  }

  final bool negative = raw.startsWith('-');
  final String digits = digitsOnly(raw);
  if (digits.isEmpty) return fallback;
  final String grouped = formatGroupedDigits(digits);
  return negative ? '-$grouped' : grouped;
}

int? parseGroupedInt(String? input) {
  if (input == null) return null;
  final String digits = digitsOnly(input);
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Live thousand-separator formatter for price/amount fields.
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = digitsOnly(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final String formatted = formatGroupedDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
