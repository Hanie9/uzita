import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/utils/file_download_utils.dart';
import 'package:uzita/utils/technician_task_utils.dart';

void main() {
  test('resolveTaskAttachmentUrl uses api base for media paths (PWA CORS)', () {
    expect(
      resolveTaskAttachmentUrl('/media/service_attachments/a.png'),
      '$apiBaseUrl/media/service_attachments/a.png',
    );
  });

  test('technicianAttachmentFetchUrls prefers api media proxy', () {
    final List<String> urls = technicianAttachmentFetchUrls(<String, dynamic>{
      'id': 17,
      'attachment': '/media/service_attachments/a.png',
    });
    expect(urls.first, '$apiBaseUrl/media/service_attachments/a.png');
    expect(
      urls,
      contains('$apiBaseUrl/technician-organ/tasks/media/service_attachments/a.png'),
    );
  });

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

  test('looksLikeDownloadErrorBody detects html and json', () {
    expect(looksLikeDownloadErrorBody(<int>[0x7b, 0x22]), isTrue);
    expect(
      looksLikeDownloadErrorBody('<html><body>404</body></html>'.codeUnits),
      isTrue,
    );
    expect(looksLikeDownloadErrorBody(<int>[0x25, 0x50, 0x44, 0x46]), isFalse);
  });

  test('guessMimeType from filename', () {
    expect(
      guessMimeType('file.png', <int>[0x89, 0x50, 0x4e, 0x47]),
      'image/png',
    );
  });
}
