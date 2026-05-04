String _computeApiBaseUrl() {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://device-control.liara.run/api',
  );
}

final String apiBaseUrl = _computeApiBaseUrl();
