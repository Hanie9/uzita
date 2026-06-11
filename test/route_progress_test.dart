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

      final nearSecond = const LatLng(35.7105, 51.4005);
      final index = findActiveStepIndex(steps, nearSecond, previousIndex: 0);
      expect(index, 1);
    });

    test('estimateRemainingSeconds scales with distance', () {
      final remaining = estimateRemainingSeconds(
        totalSeconds: 600,
        totalMeters: 1000,
        remainingMeters: 500,
      );
      expect(remaining, 300);
    });

    test('formatClockTime returns HH:mm', () {
      final formatted = formatClockTime(DateTime(2026, 1, 1, 9, 5));
      expect(formatted, '09:05');
    });
  });
}
