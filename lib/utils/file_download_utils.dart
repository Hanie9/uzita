/// Shared helpers for attachment/invoice downloads (all platforms).
library;

String sanitizeDownloadFileName(String fileName) {
  final String trimmed = fileName.trim();
  if (trimmed.isEmpty) return 'download';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

String? contentTypeFromHeaders(Map<String, String> headers) {
  final String? raw = headers['content-type'] ?? headers['Content-Type'];
  if (raw == null || raw.trim().isEmpty) return null;
  return raw.split(';').first.trim().toLowerCase();
}

String guessMimeType(String fileName, List<int> bytes) {
  final String lower = fileName.toLowerCase();

  if (lower.endsWith('.pdf') || looksLikePdf(bytes)) {
    return 'application/pdf';
  }
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }

  return 'application/octet-stream';
}

String ensureDownloadExtension(String fileName, String mimeType) {
  final String base = sanitizeDownloadFileName(fileName);
  final String lower = base.toLowerCase();

  switch (mimeType) {
    case 'application/pdf':
      return lower.endsWith('.pdf') ? base : '$base.pdf';
    case 'image/png':
      return lower.endsWith('.png') ? base : '$base.png';
    case 'image/jpeg':
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return base;
      return '$base.jpg';
    case 'image/gif':
      return lower.endsWith('.gif') ? base : '$base.gif';
    case 'image/webp':
      return lower.endsWith('.webp') ? base : '$base.webp';
    default:
      return base;
  }
}

bool looksLikePdf(List<int> bytes) {
  return bytes.length >= 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;
}

bool looksLikeJsonError(List<int> bytes) {
  if (bytes.isEmpty) return false;
  final int first = bytes.first;
  return first == 0x7b || first == 0x5b; // { or [
}

bool looksLikeHtmlError(List<int> bytes) {
  if (bytes.isEmpty) return false;
  final String head = String.fromCharCodes(
    bytes.take(32),
  ).toLowerCase();
  return head.contains('<!doctype') ||
      head.contains('<html') ||
      head.trimLeft().startsWith('<');
}

bool looksLikeDownloadErrorBody(List<int> bytes) {
  return looksLikeJsonError(bytes) || looksLikeHtmlError(bytes);
}

String resolveDownloadMimeType({
  required String fileName,
  required List<int> bytes,
  String? contentType,
}) {
  final String? headerType = contentType?.trim().toLowerCase();
  if (headerType != null &&
      headerType.isNotEmpty &&
      headerType != 'application/octet-stream') {
    return headerType;
  }
  return guessMimeType(fileName, bytes);
}
