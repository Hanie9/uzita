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
      durationText: '3 min',
      distanceMeters: 1000,
      durationSeconds: 180,
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

  test('uses distance-share baseline when step locations are missing', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '500 متر',
      durationText: '3 دقیقه',
      distanceMeters: 500,
      durationSeconds: 120,
    );
    const legWithDistance = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '5 min',
      distanceMeters: 2000,
      durationSeconds: 300,
      steps: const [],
    );
    const baselineWithDistance = NeshanRouteLeg(
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
          durationSeconds: 60,
        ),
      ],
    );
    expect(
      trafficLevelForStep(
        step,
        liveLeg: legWithDistance,
        baselineLeg: baselineWithDistance,
      ),
      RouteTrafficLevel.heavy,
    );
  });

  test('marks moderately delayed steps as semi-heavy traffic', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'ولیعصر',
      distanceText: '800 متر',
      durationText: '2 دقیقه',
      distanceMeters: 800,
      durationSeconds: 150,
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
          durationSeconds: 72,
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
      isStepCongested(
        step,
        liveLeg: liveLeg,
        baselineLeg: matchedBaselineLeg,
        stepIndex: 0,
      ),
      isFalse,
    );
  });

  test('marks smooth flowing traffic as orange level', () {
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'اتوبان',
      distanceText: '2 کیلومتر',
      durationText: '2 دقیقه',
      distanceMeters: 2000,
      durationSeconds: 180,
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
          durationSeconds: 100,
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
      RouteTrafficLevel.smooth,
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
          durationSeconds: 119,
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

  test('leg calibration keeps uniformly slower steps clear', () {
    const liveLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '4 min',
      distanceMeters: 2000,
      durationSeconds: 240,
      steps: [],
    );
    const baselineLeg = NeshanRouteLeg(
      summary: 'test',
      distanceText: '2 km',
      durationText: '2 min',
      distanceMeters: 2000,
      durationSeconds: 120,
      steps: [
        NeshanRouteStep(
          instruction: 'ادامه دهید',
          name: 'اتوبان',
          distanceText: '1 km',
          durationText: '1 دقیقه',
          distanceMeters: 1000,
          durationSeconds: 60,
          startLocation: NeshanLatLng(latitude: 35.701, longitude: 51.391),
        ),
      ],
    );
    const step = NeshanRouteStep(
      instruction: 'ادامه دهید',
      name: 'اتوبان',
      distanceText: '1 km',
      durationText: '2 دقیقه',
      distanceMeters: 1000,
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
      expect(geometry.segments.first.trafficLevel, RouteTrafficLevel.heavy);
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

  test('extractGeocodeQuery strips city prefix for POI lookup', () {
    expect(extractGeocodeQuery('کاشان, دانشگاه کاشان'), 'دانشگاه کاشان');
    expect(
      extractGeocodeQuery('تهران، پارک علم و فناوری علم و صنعت'),
      'پارک علم و فناوری علم و صنعت',
    );
  });

  test('prefers university POI over Kashan city centre', () {
    const result = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 33.985, longitude: 51.41),
      city: 'کاشان',
      candidates: [
        NeshanGeocodingCandidate(
          location: NeshanLatLng(latitude: 33.985, longitude: 51.41),
          city: 'کاشان',
          neighbourhood: 'مرکز شهر',
          unMatchedTerm: '',
        ),
        NeshanGeocodingCandidate(
          location: NeshanLatLng(latitude: 34.014, longitude: 51.364),
          city: 'کاشان',
          neighbourhood: 'راوند',
          title: 'دانشگاه کاشان',
          formattedAddress: 'کاشان، بلوار قطب راوندی',
          unMatchedTerm: '',
        ),
      ],
    );

    final refined = refineGeocodingResult(
      result,
      address: 'کاشان, دانشگاه کاشان',
    );

    expect(refined.location.latitude, closeTo(34.014, 0.01));
    expect(refined.title, 'دانشگاه کاشان');
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
          formattedAddress: 'اصفهان، خیابان چهارباغ',
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
