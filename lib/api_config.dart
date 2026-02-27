import 'package:flutter/foundation.dart' show kIsWeb;

String _computeApiBaseUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    // If hosted on uzita-iot.ir (same origin as API), use relative path to avoid CORS
    if (origin.contains('uzita-iot.ir')) {
      return '/api';
    }
  }
  // Default to public API domain (requires CORS if different origin)
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://91.92.214.193:4033/api',
  );
}

final String apiBaseUrl = _computeApiBaseUrl();
