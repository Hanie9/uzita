import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';

/// Straight-line fallback when Neshan routing API is unavailable.
/// Map still opens with origin/destination on the Neshan SDK.
NeshanRoute buildDegradedDirectRoute({
  required NeshanLatLng origin,
  required NeshanLatLng destination,
}) {
  const distance = Distance();
  final from = LatLng(origin.latitude, origin.longitude);
  final to = LatLng(destination.latitude, destination.longitude);
  final meters = distance(from, to);
  final durationSeconds =
      (meters / 9.0).clamp(60.0, 86400.0).toDouble();

  String distanceText;
  if (meters >= 1000) {
    distanceText = '${(meters / 1000).toStringAsFixed(1)} کیلومتر';
  } else {
    distanceText = '${meters.round()} متر';
  }

  final minutes = (durationSeconds / 60).round();
  final durationText = minutes < 60
      ? '$minutes دقیقه'
      : '${minutes ~/ 60} ساعت و ${minutes % 60} دقیقه';

  return NeshanRoute(
    legs: [
      NeshanRouteLeg(
        summary: 'مسیر مستقیم (تقریبی)',
        distanceText: distanceText,
        distanceMeters: meters,
        durationText: durationText,
        durationSeconds: durationSeconds,
        steps: [
          const NeshanRouteStep(
            instruction: 'حرکت به سمت مقصد',
            name: '',
            distanceText: '',
            durationText: '',
            stepType: 'depart',
          ),
          const NeshanRouteStep(
            instruction: 'رسیدن به مقصد',
            name: '',
            distanceText: '',
            durationText: '',
            stepType: 'arrive',
          ),
        ],
      ),
    ],
  );
}
