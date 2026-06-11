import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/neshan_api_codes.dart';

void main() {
  test('maps Neshan error code 484 to ApiWhiteListError', () {
    expect(
      neshanStatusFromResponse({
        'status': 'ERROR',
        'code': 484,
        'message': 'API Key scope (ip, domain or bundle) did not match.',
      }),
      'ApiWhiteListError',
    );
  });

  test('keeps explicit non-error status values', () {
    expect(
      neshanStatusFromResponse({'status': 'ApiServiceListError', 'code': 485}),
      'ApiServiceListError',
    );
  });
}
