import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/neshan_api_codes.dart';

void main() {
  test('maps Neshan error codes 481 and 482 per official docs', () {
    expect(
      neshanStatusFromResponse({'status': 'ERROR', 'code': 481}),
      'LimitExceeded',
    );
    expect(
      neshanStatusFromResponse({'status': 'ERROR', 'code': 482}),
      'RateExceeded',
    );
  });

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
