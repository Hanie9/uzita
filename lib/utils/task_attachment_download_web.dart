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

  final html.Blob blob = html.Blob(
    <Uint8List>[Uint8List.fromList(bytes)],
    mimeType,
  );
  final String url = html.Url.createObjectUrlFromBlob(blob);

  if (mimeType == 'application/pdf') {
    final html.WindowBase? opened = html.window.open(url, '_blank');
    if (opened == null) {
      _triggerAnchorDownload(url, safeName);
    }
  } else {
    _triggerAnchorDownload(url, safeName);
  }

  Future<void>.delayed(const Duration(seconds: 15), () {
    html.Url.revokeObjectUrl(url);
  });
}

void _triggerAnchorDownload(String blobUrl, String fileName) {
  final html.AnchorElement anchor = html.AnchorElement(href: blobUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}

/// Last resort on PWA when authenticated fetch is blocked (e.g. CORS on /media/).
Future<void> openDownloadUrlInBrowser(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) return;
  html.window.open(trimmed, '_blank');
}
