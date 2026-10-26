import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/customer/customer_api.dart';

void main() {
  test('customer phone drops a leading zero and country code', () {
    expect(normalizeCustomerPhone('09123456789'), '9123456789');
    expect(normalizeCustomerPhone('9123456789'), '9123456789');
    expect(normalizeCustomerPhone('+989123456789'), '9123456789');
    expect(normalizeCustomerPhone('912345678'), isNull);
    expect(customerLoginRetryUsername('09355191018'), '9355191018');
    expect(customerLoginRetryUsername('9355191018'), isNull);
    expect(customerLoginNamesMatch('9355191018', '09355191018'), isTrue);
    expect(customerLoginNamesMatch('driver1', 'other'), isFalse);
  });

  test('customer errors prefer field messages', () {
    expect(
      customerErrorMessage(
        <String, dynamic>{
          'phone': <String>['این شماره تماس قبلاً ثبت‌نام کرده است.'],
        },
        'fallback',
      ),
      'این شماره تماس قبلاً ثبت‌نام کرده است.',
    );
  });
}
