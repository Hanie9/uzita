import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uzita/app_localizations.dart';

/// Persian/Arabic digits → ASCII, strip non-digits (keep leading +).
String normalizePhoneDigits(String raw) {
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
  for (final int code in raw.runes) {
    final String ch = String.fromCharCode(code);
    if (digitMap.containsKey(ch)) {
      buffer.write(digitMap[ch]);
    } else if (ch == '+' && buffer.isEmpty) {
      buffer.write(ch);
    } else if (RegExp(r'[0-9]').hasMatch(ch)) {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

bool isCallablePhone(String? raw) {
  if (raw == null) return false;
  final String trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '---' || trimmed == '—' || trimmed == '-') {
    return false;
  }
  final String digits = normalizePhoneDigits(trimmed);
  return digits.replaceAll('+', '').length >= 7;
}

String? telUriForPhone(String raw) {
  final String digits = normalizePhoneDigits(raw);
  if (digits.replaceAll('+', '').length < 7) return null;
  return 'tel:$digits';
}

Future<void> copyPhoneToClipboard(
  BuildContext context,
  String raw, {
  String? successMessage,
}) async {
  final String digits = normalizePhoneDigits(raw);
  final String text = digits.isNotEmpty ? digits : raw.trim();
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  final AppLocalizations? loc = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(successMessage ?? loc?.phone_copied ?? 'Copied'),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> launchPhoneCall(
  BuildContext context,
  String raw, {
  String? failureMessage,
}) async {
  final String? tel = telUriForPhone(raw);
  if (tel == null) {
    await copyPhoneToClipboard(context, raw);
    return;
  }

  final Uri uri = Uri.parse(tel);
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      final AppLocalizations? loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage ?? loc?.phone_call_failed ?? 'Call failed'),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    final AppLocalizations? loc = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failureMessage ?? loc?.phone_call_failed ?? 'Call failed'),
      ),
    );
  }
}
