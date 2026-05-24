import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/utils/technician_task_utils.dart';

void main() {
  test('technicianInvoiceDownloadUrl uses api base', () {
    expect(
      technicianInvoiceDownloadUrl(15),
      '$apiBaseUrl/technician/15/invoice/download',
    );
  });

  test('taskAllowsInvoiceDownload after check-task fields on API', () {
    final Map<String, dynamic> task = <String, dynamic>{
      'id': 15,
      'sayer_hazine': '1000',
      'piece_ids': <int>[1, 2],
      'tariff_ids': <int>[3],
    };

    expect(taskAllowsInvoiceDownload(task), isTrue);
  });

  test('taskAllowsInvoiceDownload false before check-task submit', () {
    final Map<String, dynamic> task = <String, dynamic>{
      'id': 15,
      'pieces': <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'part'},
      ],
      'tariffs': <Map<String, dynamic>>[
        <String, dynamic>{'id': 2, 'name': 'tariff'},
      ],
      'hazine': '0',
      'time': '0',
    };

    expect(taskAllowsInvoiceDownload(task), isFalse);
  });

  test('parseHttpDownloadFileName reads Content-Disposition', () {
    expect(
      parseHttpDownloadFileName(
        <String, String>{
          'content-disposition': 'attachment; filename="invoice-15.pdf"',
        },
        defaultName: 'invoice_15.pdf',
      ),
      'invoice-15.pdf',
    );
  });
}
