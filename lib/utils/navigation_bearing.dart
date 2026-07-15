import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/route_progress.dart';

double normalizeBearingDegrees(double degrees) {
  var value = degrees % 360;
  if (value < 0) value += 360;
  return value;
}

/// Smooth bearing changes and handle 359° ↔ 1° wrap-around.
double smoothBearingDegrees(double? previous, double next, {double alpha = 0.38}) {
  final normalized = normalizeBearingDegrees(next);
  if (previous == null) return normalized;

  var delta = normalized - previous;
  while (delta > 180) {
    delta -= 360;
  }
  while (delta < -180) {
    delta += 360;
  }
  return normalizeBearingDegrees(previous + delta * alpha);
}

double blendBearingTowardRoute(
  double deviceBearing,
  double routeBearing, {
  double maxPull = 0.22,
  double maxDelta = 55,
}) {
  var delta = routeBearing - deviceBearing;
  while (delta > 180) {
    delta -= 360;
  }
  while (delta < -180) {
    delta += 360;
  }
  if (delta.abs() > maxDelta) {
    return normalizeBearingDegrees(deviceBearing);
  }
  return normalizeBearingDegrees(deviceBearing + delta * maxPull);
}

/// Bearing for heading-up navigation: locked to the route polyline.
///
/// The map keeps a stable angle like Neshan — it does not spin with GPS noise
/// or phone rotation. Bearing only changes when the driver advances to the
/// next route segment (a turn).
double? resolveNavigationBearing({
  required LatLng position,
  double? deviceHeading,
  double speedMps = 0,
  LatLng? previousPosition,
  List<LatLng> routePolyline = const [],
  bool navigationActive = false,
  double? lastKnownBearing,
  int? lastRouteSegmentIndex,
}) {
  if (navigationActive) {
    return resolveRouteLockedNavigationBearing(
      position: position,
      routePolyline: routePolyline,
      lastKnownBearing: lastKnownBearing,
      lastRouteSegmentIndex: lastRouteSegmentIndex,
    );
  }

  double? primary;

  if (deviceHeading != null &&
      deviceHeading >= 0 &&
      deviceHeading <= 360 &&
      speedMps >= 0.25) {
    primary = normalizeBearingDegrees(deviceHeading);
  } else if (previousPosition != null &&
      distanceMeters(previousPosition, position) >= 3) {
    primary = normalizeBearingDegrees(
      const Distance().bearing(previousPosition, position),
    );
  }

  final routeBearing = bearingAlongPolyline(routePolyline, position);
  return primary ?? routeBearing;
}

/// Route-segment bearing: stable on straight sections, updates only at turns.
double? resolveRouteLockedNavigationBearing({
  required LatLng position,
  List<LatLng> routePolyline = const [],
  double? lastKnownBearing,
  int? lastRouteSegmentIndex,
}) {
  if (routePolyline.length < 2) return lastKnownBearing;

  final index = resolveLockedRouteSegmentIndex(
    routePolyline,
    position,
    lastRouteSegmentIndex,
  );
  final segmentBearing =
      bearingAheadOnPolyline(routePolyline, position) ??
      bearingAlongPolyline(routePolyline, position);
  if (segmentBearing == null) return lastKnownBearing;

  if (lastRouteSegmentIndex == index && lastKnownBearing != null) {
    return lastKnownBearing;
  }

  if (lastKnownBearing == null) {
    return normalizeBearingDegrees(segmentBearing);
  }

  final blended = smoothBearingDegrees(
    lastKnownBearing,
    segmentBearing,
    alpha: 0.28,
  );
  if (bearingDeltaDegrees(lastKnownBearing, blended) < 6) {
    return lastKnownBearing;
  }
  return blended;
}

/// Segment index with forward-only hysteresis (prevents GPS jitter near vertices).
int resolveLockedRouteSegmentIndex(
  List<LatLng> routePolyline,
  LatLng position,
  int? lastRouteSegmentIndex,
) {
  final raw = findClosestPolylineIndex(routePolyline, position).clamp(
    0,
    routePolyline.length - 2,
  );
  if (lastRouteSegmentIndex == null) return raw;
  if (raw < lastRouteSegmentIndex) return lastRouteSegmentIndex;
  return raw;
}

/// Segment index paired with [resolveRouteLockedNavigationBearing].
int? routeSegmentIndexForPosition(List<LatLng> routePolyline, LatLng position) {
  if (routePolyline.length < 2) return null;
  return findClosestPolylineIndex(routePolyline, position).clamp(
    0,
    routePolyline.length - 2,
  );
}

double bearingDeltaDegrees(double a, double b) {
  var delta = (normalizeBearingDegrees(b) - normalizeBearingDegrees(a)).abs();
  if (delta > 180) delta = 360 - delta;
  return delta;
}
