/// Known Neshan API error codes (HTTP status and JSON `code` field).
String? neshanStatusFromResponse(Map<String, dynamic> data) {
  final explicit = data['status']?.toString();
  if (explicit != null &&
      explicit != 'ERROR' &&
      explicit != 'OK' &&
      explicit.isNotEmpty) {
    return explicit;
  }

  final code = data['code'];
  if (code is num) {
    switch (code.toInt()) {
      case 480:
        return 'KeyNotFound';
      case 483:
        return 'ApiKeyTypeError';
      case 484:
        return 'ApiWhiteListError';
      case 485:
        return 'ApiServiceListError';
      case 486:
        return 'RateExceeded';
      case 487:
        return 'LimitExceeded';
    }
  }

  return explicit;
}
