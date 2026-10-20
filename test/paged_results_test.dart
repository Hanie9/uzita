import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/paged_results.dart';

void main() {
  const String endpoint =
      'https://device-control.liara.run/api/transport/report';

  test('parseReportPage reads results, count, and absolute next url', () {
    final ReportPagePayload page = parseReportPage(<String, dynamic>{
      'count': 30,
      'next': '$endpoint?page=2',
      'results': <Map<String, dynamic>>[
        <String, dynamic>{'id': 1},
      ],
    }, listEndpoint: endpoint);

    expect(page.totalCount, 30);
    expect(page.nextUrl, '$endpoint?page=2');
    expect(page.results, hasLength(1));
  });

  test('parseReportPage turns a numeric next page into a url', () {
    final ReportPagePayload page = parseReportPage(<String, dynamic>{
      'next': 3,
      'results': <dynamic>[],
    }, listEndpoint: endpoint);

    expect(page.nextUrl, '$endpoint?page=3');
  });

  test('appendUniqueReports skips duplicate ids and keeps new rows', () {
    final List<Map<String, dynamic>> merged = appendUniqueReports(
      <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'mabda': 'a'},
      ],
      <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'mabda': 'duplicate'},
        <String, dynamic>{'id': 2, 'mabda': 'b'},
      ],
    );

    expect(merged.map((Map<String, dynamic> row) => row['id']), <int>[1, 2]);
    expect(merged.first['mabda'], 'a');
  });
}
