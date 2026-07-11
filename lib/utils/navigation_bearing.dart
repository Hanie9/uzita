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

/// Bearing for heading-up navigation: compass / GPS first, route as fallback.
double? resolveNavigationBearing({
  required LatLng position,
  double? compassHeading,
  double? deviceHeading,
  double speedMps = 0,
  LatLng? previousPosition,
  List<LatLng> routePolyline = const [],
  bool navigationActive = false,
}) {
  double? primary;

  if (navigationActive &&
      compassHeading != null &&
      compassHeading >= 0 &&
      compassHeading <= 360) {
    primary = normalizeBearingDegrees(compassHeading);
  } else if (deviceHeading != null &&
      deviceHeading >= 0 &&
      deviceHeading <= 360 &&
      (!navigationActive || speedMps >= 0.25)) {
    primary = normalizeBearingDegrees(deviceHeading);
  } else if (previousPosition != null &&
      distanceMeters(previousPosition, position) >= 3) {
    primary = normalizeBearingDegrees(
      const Distance().bearing(previousPosition, position),
    );
  }

  final routeBearing = bearingAlongPolyline(routePolyline, position);

  if (primary != null && routeBearing != null && navigationActive) {
    return blendBearingTowardRoute(primary, routeBearing);
  }

  return primary ?? routeBearing;
}

double bearingDeltaDegrees(double a, double b) {
  var delta = (normalizeBearingDegrees(b) - normalizeBearingDegrees(a)).abs();
  if (delta > 180) delta = 360 - delta;
  return delta;
}
