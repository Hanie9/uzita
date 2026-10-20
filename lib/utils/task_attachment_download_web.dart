import 'dart:html' as html;
import 'dart:typed_data';

import 'package:uzita/utils/file_download_utils.dart';

Future<void> saveTaskAttachmentFile({
  required List<int> bytes,
  required String fileName,
  String? contentType,
}) async {
  final String mimeType = resolveDownloadMimeType(
    fileName: fileName,
    bytes: bytes,
    contentType: contentType,
  );
  final String safeName = ensureDownloadExtension(
    sanitizeDownloadFileName(fileName),
    mimeType,
  );

  final html.Blob blob = html.Blob(<Uint8List>[
    Uint8List.fromList(bytes),
  ], mimeType);
  final String url = html.Url.createObjectUrlFromBlob(blob);

  final bool viewInBrowser =
      mimeType == 'application/pdf' || mimeType.startsWith('image/');

  if (viewInBrowser) {
    html.window.open(url, '_blank');
  } else {
    _triggerAnchorDownload(url, safeName);
  }

  Future<void>.delayed(const Duration(seconds: 60), () {
    html.Url.revokeObjectUrl(url);
  });
}

void _triggerAnchorDownload(String blobUrl, String fileName) {
  final html.AnchorElement anchor = html.AnchorElement(href: blobUrl)
    ..download = fileName
    ..rel = 'noopener'
    ..style.position = 'fixed'
    ..style.left = '-1000px'
    ..style.top = '0';
  html.document.body?.append(anchor);
  anchor.click();
  // Removing the link in the same turn cancels the download in mobile browsers.
  Future<void>.delayed(const Duration(seconds: 2), () {
    anchor.remove();
  });
}

/// Last resort on PWA when authenticated fetch is blocked.
Future<void> openDownloadUrlInBrowser(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) return;
  html.window.open(trimmed, '_blank');
}
