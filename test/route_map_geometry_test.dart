import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/address_geocode_hints.dart';
import 'package:uzita/utils/neshan_traffic_levels.dart';
import 'package:uzita/utils/route_map_geometry.dart';

void main() {
  const liveLeg = NeshanRouteLeg(
    summary: 'test',
    distanceText: '2 km',
    durationText: '5 min',
    distanceMeters: 2000,
    durationSeconds: 300,
    steps: [],
  );

  const baselineLeg = NeshanRouteLeg(
    summary: 'test',
    distanceText: '2 km',
    durationText: '3 min',
    distanceMeters: 2000,
    durationSeconds: 180,
    steps: [],
  );

  test('uses matching baseline step duration when start locations align', () {
    const liveLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '1 km',
      durationText: '4 min',
      distanceMeters: 1000,
      durationSeconds: 240,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'ولیعصر',
          distanceText: '500 متر',
          durationText: '3 دقیقه',
          distanceMeters: 500,
          durationSeconds: 120,
          startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
        ),
      ],
    );

    const baselineLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '1 km',
      durationText: '2 min',
      distanceMeters: 1000,
      durationSeconds: 120,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'ولیعصر',
          distanceText: '500 متر',
          durationText: '1 دقیقه',
          distanceMeters: 500,
          durationSeconds: 60,
          startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
        ),
      ],
    );

    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '500 متر',
      durationText: '3 دقیقه',
      distanceMeters: 500,
      durationSeconds: 120,
      startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
    );

    expect(
      trafficLevelForStep(
        step,
        liveLeg: liveLeg,
        baselineLeg: baselineLeg,
        stepIndex: 0,
      ),
      RouteTrafficLevel.heavy,
    );
  });

  test('marks heavily delayed steps using Neshan leg baseline', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '500 متر',
      durationText: '3 دقیقه',
      distanceMeters: 500,
      durationSeconds: 120,
      startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
    );
    const matchedBaselineLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '3 min',
      distanceMeters: 2000,
      durationSeconds: 180,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'ولیعصر',
          distanceText: '500 متر',
          durationText: '1 دقیقه',
          distanceMeters: 500,
          durationSeconds: 50,
          startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
        ),
      ],
    );
    expect(
      trafficLevelForStep(
        step,
        liveLeg: liveLeg,
        baselineLeg: matchedBaselineLeg,
        stepIndex: 0,
      ),
      RouteTrafficLevel.heavy,
    );
    expect(
      isStepCongested(
        step,
        liveLeg: liveLeg,
        baselineLeg: matchedBaselineLeg,
        stepIndex: 0,
      ),
      isTrue,
    );
  });

  test('does not guess traffic from proportional baseline allocation', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '500 متر',
      durationText: '3 دقیقه',
      distanceMeters: 500,
      durationSeconds: 120,
    );
    expect(
      trafficLevelForStep(step, liveLeg: liveLeg, baselineLeg: baselineLeg),
      RouteTrafficLevel.clear,
    );
  });

  test('marks moderately delayed steps as orange traffic', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '800 متر',
      durationText: '2 دقیقه',
      distanceMeters: 800,
      durationSeconds: 90,
      startLocation: NeshanLatLng(latitude: 35.702, longitude: 51.392),
    );
    const matchedBaselineLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '3 min',
      distanceMeters: 2000,
      durationSeconds: 180,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'ولیعصر',
          distanceText: '800 متر',
          durationText: '1 دقیقه',
          distanceMeters: 800,
          durationSeconds: 60,
          startLocation: NeshanLatLng(latitude: 35.702, longitude: 51.392),
        ),
      ],
    );
    expect(
      trafficLevelForStep(
        step,
        liveLeg: liveLeg,
        baselineLeg: matchedBaselineLeg,
        stepIndex: 0,
      ),
      RouteTrafficLevel.moderate,
    );
    expect(
      isStepCongested(step, liveLeg: liveLeg, baselineLeg: baselineLeg),
      isFalse,
    );
  });

  test('marks similar durations as clear traffic', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'اتوبان',
      distanceText: '2 کیلومتر',
      durationText: '2 دقیقه',
      distanceMeters: 2000,
      durationSeconds: 120,
      startLocation: NeshanLatLng(latitude: 35.703, longitude: 51.393),
    );
    const matchedBaselineLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '3 min',
      distanceMeters: 2000,
      durationSeconds: 180,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'اتوبان',
          distanceText: '2 کیلومتر',
          durationText: '2 دقیقه',
          distanceMeters: 2000,
          durationSeconds: 110,
          startLocation: NeshanLatLng(latitude: 35.703, longitude: 51.393),
        ),
      ],
    );
    expect(
      trafficLevelForStep(
        step,
        liveLeg: liveLeg,
        baselineLeg: matchedBaselineLeg,
        stepIndex: 0,
      ),
      RouteTrafficLevel.clear,
    );
  });

  test(
    'builds colored segments from overview polyline when step polyline missing',
    () {
      const route = NeshanRoute(
        overviewPolyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        legs: [
          NeshanRouteLeg(
            summary: 'test',
            distanceText: '1 km',
            durationText: '2 min',
            distanceMeters: 1000,
            durationSeconds: 120,
            steps: [
              NeshanRouteStep(
                instruction: 'شروع',
                name: 'خیابان',
                distanceText: '500 m',
                durationText: '1 min',
                distanceMeters: 500,
                durationSeconds: 90,
                stepType: 'depart',
              ),
              NeshanRouteStep(
                instruction: 'رسیدن',
                name: '',
                distanceText: '',
                durationText: '',
                stepType: 'arrive',
              ),
            ],
          ),
        ],
        baselineRoute: NeshanRoute(
          legs: [
            NeshanRouteLeg(
              summary: 'test',
              distanceText: '1 km',
              durationText: '1 min',
              distanceMeters: 1000,
              durationSeconds: 60,
              steps: const [],
            ),
          ],
        ),
      );

      final geometry = RouteMapGeometry.fromRoute(
        route,
        origin: const LatLng(38.5, -120.2),
        destination: const LatLng(40.7, -120.95),
      );

      expect(geometry.segments, isNotEmpty);
      expect(
        geometry.segments.every((s) => s.trafficLevel == RouteTrafficLevel.clear),
        isTrue,
      );
    },
  );

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

  test(
    'buildGeocodeParams uses city centroid not origin for different city',
    () {
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
    },
  );

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
