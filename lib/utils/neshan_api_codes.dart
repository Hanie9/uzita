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
      case 400:
        return 'INVALID_ARGUMENT';
      case 470:
        return 'CoordinateParseError';
      case 480:
        return 'KeyNotFound';
      case 483:
        return 'ApiKeyTypeError';
      case 484:
        return 'ApiWhiteListError';
      case 481:
        return 'LimitExceeded';
      case 482:
        return 'RateExceeded';
      case 485:
        return 'ApiServiceListError';
    }
  }

  return explicit;
}
