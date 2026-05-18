String _computeApiBaseUrl() {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://device-control.liara.run/api',
  );
}

final String apiBaseUrl = _computeApiBaseUrl();

/// Origin for media files (`/media/...`), without `/api`.
String get apiOrigin {
  final Uri uri = Uri.parse(apiBaseUrl);
  return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
}

/// Builds full download URL for task `attachment` from organ/personal APIs.
///
/// API returns a path such as `/media/service_attachments/...` — served from
/// site origin `https://device-control.liara.run`, not under `/api`.
String resolveTaskAttachmentUrl(String attachment) {
  final String trimmed = attachment.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  final Uri base = Uri.parse(apiBaseUrl);

  if (trimmed.startsWith('/api/')) {
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: trimmed,
    ).toString();
  }

  if (trimmed.startsWith('/')) {
    return '$apiOrigin$trimmed';
  }

  return '$apiOrigin/$trimmed';
}
