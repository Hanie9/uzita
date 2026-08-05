import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/number_format_utils.dart';

void main() {
  test('formatGroupedDigits groups from the right', () {
    expect(formatGroupedDigits('1'), '1');
    expect(formatGroupedDigits('12'), '12');
    expect(formatGroupedDigits('123'), '123');
    expect(formatGroupedDigits('1234'), '1,234');
    expect(formatGroupedDigits('1234567'), '1,234,567');
  });

  test('formatGroupedNumber handles numbers and placeholders', () {
    expect(formatGroupedNumber(1500000), '1,500,000');
    expect(formatGroupedNumber('25000'), '25,000');
    expect(formatGroupedNumber(null), '---');
    expect(formatGroupedNumber('---'), '---');
  });

  test('parseGroupedInt strips separators', () {
    expect(parseGroupedInt('1,234,567'), 1234567);
    expect(parseGroupedInt('۱٬۲۳۴'), 1234);
    expect(parseGroupedInt(''), null);
  });
}
