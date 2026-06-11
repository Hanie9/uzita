import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/polyline_decoder.dart';

void main() {
  test('decodePolyline returns empty list for empty input', () {
    expect(decodePolyline(''), isEmpty);
  });

  test('decodePolyline decodes known polyline', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points.first.latitude, closeTo(38.5, 0.01));
    expect(points.first.longitude, closeTo(-120.2, 0.01));
  });
}
