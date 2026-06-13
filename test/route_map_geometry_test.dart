import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/address_geocode_hints.dart';
import 'package:uzita/utils/route_map_geometry.dart';

void main() {
  test('marks slow steps as congested', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '500 متر',
      durationText: '3 دقیقه',
      distanceMeters: 500,
      durationSeconds: 180,
    );
    expect(isStepCongested(step), isTrue);
  });

  test('builds geometry from overview polyline', () {
    const route = NeshanRoute(
      legs: [],
      overviewPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
    );
    final geometry = RouteMapGeometry.fromRoute(
      route,
      origin: const LatLng(38.5, -120.2),
      destination: const LatLng(40.7, -120.95),
    );
    expect(geometry.fullPolyline.length, greaterThan(2));
    expect(geometry.segments, isNotEmpty);
    expect(geometry.fullPolyline.first.latitude, 38.5);
    expect(geometry.fullPolyline.last.latitude, 40.7);
  });

  test('extracts city hints from Persian address', () {
    final hints = extractGeocodeHints('تهران، میدان انقلاب، خیابان آزادی');
    expect(hints.city, 'تهران');
    expect(hints.province, 'تهران');
  });

  test('rejects implausible coordinates outside Iran', () {
    expect(
      isPlausibleIranCoordinate(
        const NeshanLatLng(latitude: 51.0, longitude: 35.0),
      ),
      isFalse,
    );
    expect(
      isPlausibleIranCoordinate(
        const NeshanLatLng(latitude: 35.7, longitude: 51.4),
      ),
      isTrue,
    );
  });
}
