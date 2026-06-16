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

/// Closest point lying exactly on [polyline] to [point] (map-matching/snap).
LatLng snapPointToPolyline(List<LatLng> polyline, LatLng point) {
  if (polyline.isEmpty) return point;
  if (polyline.length == 1) return polyline.first;

  var best = polyline.first;
  var bestDistance = double.infinity;
  for (var i = 0; i < polyline.length - 1; i++) {
    final projection = _projectPointOnSegment(polyline[i], polyline[i + 1], point);
    final d = distanceMeters(point, projection);
    if (d < bestDistance) {
      bestDistance = d;
      best = projection;
    }
  }
  return best;
}

/// Shortest distance (meters) from [point] to the [polyline] (point→segment).
double distanceToPolylineMeters(List<LatLng> polyline, LatLng point) {
  if (polyline.isEmpty) return double.infinity;
  if (polyline.length == 1) return distanceMeters(point, polyline.first);

  var closest = double.infinity;
  for (var i = 0; i < polyline.length - 1; i++) {
    final projection = _projectPointOnSegment(polyline[i], polyline[i + 1], point);
    final d = distanceMeters(point, projection);
    if (d < closest) closest = d;
  }
  return closest;
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

double polylineLengthMeters(
  List<LatLng> polyline, {
  int startIndex = 0,
  int? endIndex,
}) {
  if (polyline.length < 2 || startIndex >= polyline.length - 1) return 0;

  final lastIndex = (endIndex ?? polyline.length - 1).clamp(
    startIndex,
    polyline.length - 1,
  );

  var total = 0.0;
  for (var i = startIndex; i < lastIndex; i++) {
    total += distanceMeters(polyline[i], polyline[i + 1]);
  }
  return total;
}

/// Extracts a polyline slice between [startMeters] and [startMeters + lengthMeters].
List<LatLng> slicePolylineByDistance(
  List<LatLng> polyline,
  double startMeters,
  double lengthMeters,
) {
  if (polyline.length < 2 || lengthMeters <= 0) return const [];

  final total = polylineLengthMeters(polyline);
  if (total <= 0) return const [];

  final start = startMeters.clamp(0.0, total);
  final end = (startMeters + lengthMeters).clamp(0.0, total);
  if (end <= start + 1) return const [];

  final startPoint = _pointAtDistance(polyline, start);
  final endPoint = _pointAtDistance(polyline, end);
  if (startPoint == null || endPoint == null) return const [];

  final startIndex = findClosestPolylineIndex(polyline, startPoint);
  final endIndex = findClosestPolylineIndex(polyline, endPoint).clamp(
    startIndex,
    polyline.length - 1,
  );

  final slice = <LatLng>[startPoint];
  if (endIndex > startIndex) {
    slice.addAll(polyline.sublist(startIndex + 1, endIndex + 1));
  }
  if (slice.isEmpty || slice.last != endPoint) {
    slice.add(endPoint);
  }

  return slice.length >= 2 ? slice : const [];
}

LatLng? _pointAtDistance(List<LatLng> polyline, double targetMeters) {
  if (polyline.isEmpty) return null;
  if (targetMeters <= 0) return polyline.first;

  var walked = 0.0;
  for (var i = 0; i < polyline.length - 1; i++) {
    final segmentLength = distanceMeters(polyline[i], polyline[i + 1]);
    if (walked + segmentLength >= targetMeters) {
      final remaining = targetMeters - walked;
      final t = segmentLength <= 0 ? 0.0 : (remaining / segmentLength).clamp(0.0, 1.0);
      return LatLng(
        polyline[i].latitude +
            (polyline[i + 1].latitude - polyline[i].latitude) * t,
        polyline[i].longitude +
            (polyline[i + 1].longitude - polyline[i].longitude) * t,
      );
    }
    walked += segmentLength;
  }
  return polyline.last;
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

/// True when [point] is plausibly on/near the planned route (not emulator default GPS).
bool isNearRoutePolyline({
  required LatLng point,
  required List<LatLng> polyline,
  required LatLng origin,
  required LatLng destination,
  double maxMeters = 25000,
}) {
  if (distanceMeters(point, origin) <= maxMeters) return true;
  if (distanceMeters(point, destination) <= maxMeters) return true;
  if (polyline.isEmpty) return false;

  var closest = double.infinity;
  for (final routePoint in polyline) {
    final d = distanceMeters(point, routePoint);
    if (d < closest) closest = d;
  }
  return closest <= maxMeters;
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

/// Distance from [driver] to the start of [step] along the route when possible.
double distanceToStepMeters({
  required LatLng driver,
  required NeshanRouteStep step,
  required List<LatLng> routePolyline,
}) {
  if (routePolyline.length >= 2) {
    final driverIndex = findClosestPolylineIndex(routePolyline, driver);
    final loc = step.startLocation;
    if (loc != null) {
      final stepPoint = LatLng(loc.latitude, loc.longitude);
      final stepIndex = findClosestPolylineIndex(routePolyline, stepPoint);
      if (stepIndex > driverIndex) {
        return polylineLengthMeters(
          routePolyline,
          startIndex: driverIndex,
          endIndex: stepIndex + 1,
        );
      }
      return distanceMeters(driver, stepPoint);
    }
    return polylineLengthMeters(routePolyline, startIndex: driverIndex);
  }

  final loc = step.startLocation;
  if (loc != null) {
    return distanceMeters(driver, LatLng(loc.latitude, loc.longitude));
  }
  return 0;
}
