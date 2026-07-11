import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/navigation_bearing.dart';

void main() {
  test('smoothBearingDegrees handles wrap-around', () {
    final smoothed = smoothBearingDegrees(350, 10, alpha: 1);
    expect(smoothed, closeTo(10, 0.01));
  });

  test('resolveNavigationBearing prefers compass in navigation', () {
    const position = LatLng(35.70, 51.39);
    final bearing = resolveNavigationBearing(
      position: position,
      compassHeading: 95,
      deviceHeading: 180,
      routePolyline: const [
        LatLng(35.70, 51.39),
        LatLng(35.71, 51.40),
      ],
      navigationActive: true,
    );
    expect(bearing, isNotNull);
    expect(bearing!, greaterThan(80));
    expect(bearing, lessThan(110));
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
