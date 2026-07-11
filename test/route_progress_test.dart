import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_progress.dart';

void main() {
  group('route_progress', () {
    test('findActiveStepIndex advances along route', () {
      final steps = [
        NeshanRouteStep(
          instruction: 'start',
          name: '',
          distanceText: '',
          durationText: '',
          startLocation: const NeshanLatLng(latitude: 35.70, longitude: 51.39),
        ),
        NeshanRouteStep(
          instruction: 'turn',
          name: '',
          distanceText: '',
          durationText: '',
          startLocation: const NeshanLatLng(latitude: 35.71, longitude: 51.40),
        ),
      ];

      final route = [
        const LatLng(35.70, 51.39),
        const LatLng(35.705, 51.395),
        const LatLng(35.71, 51.40),
      ];
      final nearSecond = const LatLng(35.7105, 51.4005);
      final index = findActiveStepIndex(
        steps,
        nearSecond,
        previousIndex: 0,
        routePolyline: route,
      );
      expect(index, 1);
    });

    test('distanceToManeuverMeters decreases while driving a step', () {
      final steps = [
        NeshanRouteStep(
          instruction: 'depart',
          name: 'امام علی',
          distanceText: '',
          durationText: '',
          startLocation: const NeshanLatLng(latitude: 35.70, longitude: 51.39),
        ),
        NeshanRouteStep(
          instruction: 'turn left',
          name: 'خروجی',
          distanceText: '',
          durationText: '',
          startLocation: const NeshanLatLng(latitude: 35.71, longitude: 51.40),
        ),
      ];
      final route = [
        const LatLng(35.70, 51.39),
        const LatLng(35.705, 51.395),
        const LatLng(35.71, 51.40),
      ];

      final nearStart = distanceToManeuverMeters(
        driver: const LatLng(35.7005, 51.3905),
        steps: steps,
        activeIndex: 0,
        routePolyline: route,
      );
      final midSegment = distanceToManeuverMeters(
        driver: const LatLng(35.705, 51.395),
        steps: steps,
        activeIndex: 0,
        routePolyline: route,
      );

      expect(midSegment, lessThan(nearStart));
      expect(midSegment, greaterThan(0));
    });

    test('estimateRemainingSeconds scales with distance', () {
      final remaining = estimateRemainingSeconds(
        totalSeconds: 600,
        totalMeters: 1000,
        remainingMeters: 500,
      );
      expect(remaining, 300);
    });

    test('remainingMetersAlongPolyline decreases while driving', () {
      const route = [
        LatLng(35.70, 51.39),
        LatLng(35.705, 51.395),
        LatLng(35.71, 51.40),
        LatLng(35.715, 51.405),
      ];
      final total = polylineLengthMeters(route);
      final nearStart = remainingMetersAlongPolyline(
        route,
        const LatLng(35.7002, 51.3902),
      );
      final midRoute = remainingMetersAlongPolyline(
        route,
        const LatLng(35.71, 51.40),
      );

      expect(nearStart, closeTo(total, 200));
      expect(midRoute, lessThan(nearStart));
      expect(midRoute, greaterThan(0));
    });

    test('remainingMetersAlongPolyline ignores snapped driver origin bug', () {
      // Simulates the old bug: polyline[0] is overwritten to current driver.
      const routeStart = LatLng(35.70, 51.39);
      const routeMid = LatLng(35.71, 51.40);
      const routeEnd = LatLng(35.72, 51.41);
      const driver = LatLng(35.71, 51.40);

      final buggyPolyline = [driver, routeStart, routeMid, routeEnd];
      final stablePolyline = [routeStart, routeMid, routeEnd];

      final buggyRemaining = remainingMetersAlongPolyline(buggyPolyline, driver);
      final stableRemaining =
          remainingMetersAlongPolyline(stablePolyline, driver);

      expect(stableRemaining, lessThan(polylineLengthMeters(stablePolyline)));
      expect(buggyRemaining, greaterThan(stableRemaining));
    });

    test('findNextGuidanceStepIndex skips passed depart steps', () {
      final steps = [
        NeshanRouteStep(
          instruction: 'حرکت به سمت گلستان',
          name: 'گلستان',
          distanceText: '',
          durationText: '',
          stepType: 'depart',
          startLocation: const NeshanLatLng(latitude: 35.70, longitude: 51.39),
        ),
        NeshanRouteStep(
          instruction: 'به سمت بلوار شهید ثانی، به راست بپیچید',
          name: 'بلوار شهید ثانی',
          distanceText: '',
          durationText: '',
          stepType: 'turn',
          modifier: 'right',
          startLocation: const NeshanLatLng(latitude: 35.71, longitude: 51.40),
        ),
      ];
      const route = [
        LatLng(35.70, 51.39),
        LatLng(35.705, 51.395),
        LatLng(35.71, 51.40),
      ];

      final index = findNextGuidanceStepIndex(
        steps: steps,
        driver: const LatLng(35.7005, 51.3905),
        routePolyline: route,
      );
      expect(index, 1);
    });

    test('distanceMetersToGuidanceStep decreases while approaching turn', () {
      final step = NeshanRouteStep(
        instruction: 'به راست بپیچید',
        name: 'بلوار شهید ثانی',
        distanceText: '',
        durationText: '',
        stepType: 'turn',
        modifier: 'right',
        startLocation: const NeshanLatLng(latitude: 35.71, longitude: 51.40),
      );
      const route = [
        LatLng(35.70, 51.39),
        LatLng(35.705, 51.395),
        LatLng(35.71, 51.40),
      ];

      final far = distanceMetersToGuidanceStep(
        driver: const LatLng(35.7002, 51.3902),
        step: step,
        routePolyline: route,
      );
      final near = distanceMetersToGuidanceStep(
        driver: const LatLng(35.709, 51.399),
        step: step,
        routePolyline: route,
      );

      expect(near, lessThan(far));
      expect(near, greaterThan(0));
    });

    test('formatClockTime returns HH:mm', () {
      final formatted = formatClockTime(DateTime(2026, 1, 1, 9, 5));
      expect(formatted, '09:05');
    });
  });
}
