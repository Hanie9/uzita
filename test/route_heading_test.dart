import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/route_progress.dart';

void main() {
  test('resolveDriverHeading uses movement between points', () {
    final heading = resolveDriverHeading(
      position: const LatLng(35.7, 51.41),
      previousPosition: const LatLng(35.7, 51.40),
      routePolyline: const [],
    );

    expect(heading, isNotNull);
    expect(heading! > 80 && heading < 100, isTrue);
  });

  test('bearingAlongPolyline follows route direction', () {
    final bearing = bearingAlongPolyline(
      [
        const LatLng(35.0, 51.0),
        const LatLng(36.0, 51.0),
      ],
      const LatLng(35.5, 51.0),
    );

    expect(bearing, closeTo(0, 1));
  });
}
