Future<void> saveTaskAttachmentFile({
  required List<int> bytes,
  required String fileName,
  String? contentType,
}) {
  throw UnsupportedError('Attachment download is not supported on this platform.');
}

Future<void> openDownloadUrlInBrowser(String url) async {}
