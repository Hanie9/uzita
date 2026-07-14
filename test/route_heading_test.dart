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

  test('bearingAheadOnPolyline looks forward along the route', () {
    const polyline = [
      LatLng(35.70, 51.39),
      LatLng(35.71, 51.40),
    ];
    final ahead = bearingAheadOnPolyline(
      polyline,
      const LatLng(35.7002, 51.3902),
      meters: 30,
    );
    expect(ahead, isNotNull);
    expect(ahead!, greaterThan(30));
    expect(ahead, lessThan(60));
  });

  test('polylineAheadOf keeps only the route forward of the driver', () {
    const polyline = [
      LatLng(35.70, 51.39),
      LatLng(35.71, 51.39),
      LatLng(35.72, 51.39),
    ];
    final ahead = polylineAheadOf(
      polyline,
      const LatLng(35.705, 51.39),
    );
    expect(ahead.length, 3);
    expect(ahead.first.latitude, closeTo(35.705, 0.001));
    expect(ahead.last.latitude, closeTo(35.72, 0.001));
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
