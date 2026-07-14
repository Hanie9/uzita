import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/navigation_bearing.dart';

void main() {
  test('smoothBearingDegrees handles wrap-around', () {
    final smoothed = smoothBearingDegrees(350, 10, alpha: 1);
    expect(smoothed, closeTo(10, 0.01));
  });

  test('resolveNavigationBearing locks to route segment in navigation', () {
    const position = LatLng(35.70, 51.39);
    const polyline = [
      LatLng(35.70, 51.39),
      LatLng(35.71, 51.40),
    ];

    final first = resolveNavigationBearing(
      position: position,
      deviceHeading: 180,
      speedMps: 10,
      routePolyline: polyline,
      navigationActive: true,
    );
    expect(first, isNotNull);

    final second = resolveNavigationBearing(
      position: const LatLng(35.7005, 51.395),
      deviceHeading: 10,
      speedMps: 10,
      routePolyline: polyline,
      navigationActive: true,
      lastKnownBearing: first,
      lastRouteSegmentIndex: 0,
    );
    expect(second, first);
  });

  test('resolveNavigationBearing updates bearing at route turns', () {
    const polyline = [
      LatLng(35.70, 51.39),
      LatLng(35.71, 51.39),
      LatLng(35.71, 51.41),
    ];

    final straight = resolveRouteLockedNavigationBearing(
      position: const LatLng(35.705, 51.39),
      routePolyline: polyline,
      lastKnownBearing: 0,
      lastRouteSegmentIndex: 0,
    );
    expect(straight, 0);

    final turn = resolveRouteLockedNavigationBearing(
      position: const LatLng(35.71, 51.395),
      routePolyline: polyline,
      lastKnownBearing: 0,
      lastRouteSegmentIndex: 0,
    );
    expect(turn, isNotNull);
    expect(turn!, greaterThan(10));
    expect(turn, lessThan(90));
  });

  test('blendBearingTowardRoute keeps device bearing when far from route', () {
    final blended = blendBearingTowardRoute(10, 200);
    expect(blended, closeTo(10, 0.01));
  });

  test('bearingDeltaDegrees uses shortest arc across 0/360', () {
    expect(bearingDeltaDegrees(350, 10), closeTo(20, 0.01));
    expect(bearingDeltaDegrees(10, 350), closeTo(20, 0.01));
    expect(bearingDeltaDegrees(90, 95), closeTo(5, 0.01));
  });
}
