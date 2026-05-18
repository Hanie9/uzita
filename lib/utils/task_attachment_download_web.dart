import 'dart:html' as html;

Future<void> saveTaskAttachmentFile({
  required List<int> bytes,
  required String fileName,
}) async {
  final html.Blob blob = html.Blob(<int>[...bytes]);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
