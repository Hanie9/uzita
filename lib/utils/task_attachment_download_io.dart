import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveTaskAttachmentFile({
  required List<int> bytes,
  required String fileName,
  String? contentType,
}) async {
  final Directory dir = await getTemporaryDirectory();
  final String safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final File file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  try {
    await OpenFilex.open(file.path);
  } catch (_) {}
}

Future<void> openDownloadUrlInBrowser(String url) async {}
