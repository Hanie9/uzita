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

  test('picks Isfahan candidate when address mentions اصفهان', () {
    const result = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.7, longitude: 51.4),
      city: 'تهران',
      candidates: [
        NeshanGeocodingCandidate(
          location: NeshanLatLng(latitude: 35.7, longitude: 51.4),
          city: 'تهران',
        ),
        NeshanGeocodingCandidate(
          location: NeshanLatLng(latitude: 32.65, longitude: 51.67),
          city: 'اصفهان',
          unMatchedTerm: '',
        ),
      ],
    );

    final refined = refineGeocodingResult(
      result,
      address: 'اصفهان، خیابان چهارباغ',
    );

    expect(refined.city, 'اصفهان');
    expect(refined.location.latitude, closeTo(32.65, 0.01));
  });

  test('buildGeocodeParams uses city centroid not origin for different city', () {
    final params = buildGeocodeParams(
      address: 'خیابان نظر شرقی',
      hints: const AddressGeocodeHints(city: 'اصفهان', province: 'اصفهان'),
      originResult: const NeshanGeocodingResult(
        location: NeshanLatLng(latitude: 35.6892, longitude: 51.3890),
        city: 'تهران',
      ),
    );

    expect(params.city, 'اصفهان');
    expect(params.searchCenter?.latitude, closeTo(32.6539, 0.01));
    expect(params.searchExtent, isNotNull);
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
