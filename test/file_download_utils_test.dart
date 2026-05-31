import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/utils/file_download_utils.dart';
import 'package:uzita/utils/technician_task_utils.dart';

void main() {
  test('technicianAttachmentDownloadUrl uses api base', () {
    expect(
      technicianAttachmentDownloadUrl(17),
      '$apiBaseUrl/technician/17/attachment/download',
    );
  });

  test('ensureDownloadExtension adds pdf suffix', () {
    expect(
      ensureDownloadExtension('invoice-15', 'application/pdf'),
      'invoice-15.pdf',
    );
  });

  test('looksLikePdf detects PDF magic bytes', () {
    expect(looksLikePdf(<int>[0x25, 0x50, 0x44, 0x46, 0x2d]), isTrue);
    expect(looksLikePdf(<int>[0x7b, 0x22]), isFalse);
  });

  test('guessMimeType from filename', () {
    expect(
      guessMimeType('file.png', <int>[0x89, 0x50, 0x4e, 0x47]),
      'image/png',
    );
  });
}
