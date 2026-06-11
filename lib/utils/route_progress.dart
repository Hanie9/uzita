import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';

const Distance _distance = Distance();

double distanceMeters(LatLng a, LatLng b) => _distance(a, b);

int findClosestPolylineIndex(List<LatLng> polyline, LatLng point) {
  if (polyline.isEmpty) return 0;
  if (polyline.length == 1) return 0;

  var closestIndex = 0;
  var closestDistance = double.infinity;

  for (var i = 0; i < polyline.length - 1; i++) {
    final projection = _projectPointOnSegment(polyline[i], polyline[i + 1], point);
    final d = distanceMeters(point, projection);
    if (d < closestDistance) {
      closestDistance = d;
      closestIndex = i;
    }
  }

  return closestIndex;
}

LatLng _projectPointOnSegment(LatLng start, LatLng end, LatLng point) {
  final dx = end.longitude - start.longitude;
  final dy = end.latitude - start.latitude;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return start;

  var t =
      ((point.longitude - start.longitude) * dx +
          (point.latitude - start.latitude) * dy) /
      lengthSquared;
  t = t.clamp(0.0, 1.0);

  return LatLng(
    start.latitude + t * dy,
    start.longitude + t * dx,
  );
}

double polylineLengthMeters(List<LatLng> polyline, {int startIndex = 0}) {
  if (polyline.length < 2 || startIndex >= polyline.length - 1) return 0;

  var total = 0.0;
  for (var i = startIndex; i < polyline.length - 1; i++) {
    total += distanceMeters(polyline[i], polyline[i + 1]);
  }
  return total;
}

double estimateRemainingSeconds({
  required double totalSeconds,
  required double totalMeters,
  required double remainingMeters,
}) {
  if (totalMeters <= 0 || totalSeconds <= 0) return totalSeconds;
  final ratio = (remainingMeters / totalMeters).clamp(0.0, 1.0);
  return totalSeconds * ratio;
}

int findActiveStepIndex(
  List<NeshanRouteStep> steps,
  LatLng driver, {
  int previousIndex = 0,
}) {
  if (steps.isEmpty) return 0;

  var active = previousIndex.clamp(0, steps.length - 1);

  for (var i = previousIndex; i < steps.length; i++) {
    final location = steps[i].startLocation;
    if (location == null) continue;
    final stepPoint = LatLng(location.latitude, location.longitude);
    if (distanceMeters(driver, stepPoint) <= 100) {
      active = i;
    }
  }

  if (active < steps.length - 1) {
    final current = steps[active].startLocation;
    final next = steps[active + 1].startLocation;
    if (current != null && next != null) {
      final currentPoint = LatLng(current.latitude, current.longitude);
      final nextPoint = LatLng(next.latitude, next.longitude);
      final toNext = distanceMeters(driver, nextPoint);
      final toCurrent = distanceMeters(driver, currentPoint);
      if (toNext < toCurrent * 0.55) {
        active += 1;
      }
    }
  }

  return active.clamp(0, steps.length - 1);
}

String formatClockTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatDurationSeconds(int seconds, {required bool persian}) {
  if (seconds < 60) {
    return persian ? 'کمتر از ۱ دقیقه' : '< 1 min';
  }

  final minutes = (seconds / 60).round();
  if (minutes < 60) {
    return persian ? '$minutes دقیقه' : '$minutes min';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return persian ? '$hours ساعت' : '${hours}h';
  }
  return persian
      ? '$hours ساعت و $remainingMinutes دقیقه'
      : '${hours}h ${remainingMinutes}m';
}

List<LatLng> polylineFromIndex(List<LatLng> polyline, int startIndex) {
  if (polyline.isEmpty) return const [];
  final index = startIndex.clamp(0, polyline.length - 1);
  return polyline.sublist(index);
}

/// Bearing along the route polyline at the closest point to [point].
double? bearingAlongPolyline(List<LatLng> polyline, LatLng point) {
  if (polyline.length < 2) return null;

  final index = findClosestPolylineIndex(polyline, point).clamp(
    0,
    polyline.length - 2,
  );
  return _distance.bearing(polyline[index], polyline[index + 1]);
}

/// Resolves the best available heading for the driver arrow.
double? resolveDriverHeading({
  required LatLng position,
  double? deviceHeading,
  double speedMps = 0,
  LatLng? previousPosition,
  List<LatLng> routePolyline = const [],
}) {
  if (deviceHeading != null && speedMps > 0.8) {
    return deviceHeading % 360;
  }

  if (previousPosition != null) {
    final moved = distanceMeters(previousPosition, position);
    if (moved >= 4) {
      return _distance.bearing(previousPosition, position);
    }
  }

  return bearingAlongPolyline(routePolyline, position);
}

/// Distance from [driver] to the start of [step], or along route if no step location.
double distanceToStepMeters({
  required LatLng driver,
  required NeshanRouteStep step,
  required List<LatLng> routePolyline,
}) {
  final loc = step.startLocation;
  if (loc != null) {
    return distanceMeters(driver, LatLng(loc.latitude, loc.longitude));
  }
  if (routePolyline.isEmpty) return 0;
  final index = findClosestPolylineIndex(routePolyline, driver);
  return polylineLengthMeters(routePolyline, startIndex: index);
}
