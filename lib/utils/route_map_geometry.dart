import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/polyline_decoder.dart';

/// A drawable slice of the route (blue = clear, red = congested).
class RouteMapSegment {
  final List<LatLng> points;
  final bool congested;

  const RouteMapSegment({
    required this.points,
    required this.congested,
  });
}

class RouteMapGeometry {
  final List<LatLng> fullPolyline;
  final List<RouteMapSegment> segments;

  const RouteMapGeometry({
    required this.fullPolyline,
    required this.segments,
  });

  static RouteMapGeometry fromRoute(
    NeshanRoute route, {
    required LatLng origin,
    required LatLng destination,
  }) {
    final segments = _buildStepSegments(route);
    final overview = _decodeOverview(route.overviewPolyline);

    List<LatLng> full;
    if (overview.length >= 2) {
      full = overview;
    } else if (segments.isNotEmpty) {
      full = _concatSegments(segments);
    } else {
      full = _polylineFromStepLocations(route);
    }

    if (full.length < 2) {
      full = [origin, destination];
      return RouteMapGeometry(
        fullPolyline: full,
        segments: [
          RouteMapSegment(points: full, congested: false),
        ],
      );
    }

    full = _snapEndpoints(full, origin, destination);

    final drawSegments = segments.isNotEmpty
        ? segments
        : [RouteMapSegment(points: full, congested: false)];

    return RouteMapGeometry(fullPolyline: full, segments: drawSegments);
  }

  static List<LatLng> _decodeOverview(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    return decodePolyline(encoded);
  }

  static List<RouteMapSegment> _buildStepSegments(NeshanRoute route) {
    final leg = route.primaryLeg;
    if (leg == null || leg.steps.isEmpty) return const [];

    final segments = <RouteMapSegment>[];

    for (final step in leg.steps) {
      if (step.isArrival) continue;

      final stepPoints = _pointsForStep(step);
      if (stepPoints.length < 2) continue;

      segments.add(
        RouteMapSegment(
          points: stepPoints,
          congested: isStepCongested(step),
        ),
      );
    }

    if (segments.isNotEmpty) return segments;

    final linked = _polylineFromStepLocations(route);
    if (linked.length >= 2) {
      return [RouteMapSegment(points: linked, congested: false)];
    }

    return const [];
  }

  static List<LatLng> _polylineFromStepLocations(NeshanRoute route) {
    final leg = route.primaryLeg;
    if (leg == null) return const [];

    final points = <LatLng>[];
    for (final step in leg.steps) {
      if (step.isArrival) continue;
      final loc = step.startLocation;
      if (loc == null) continue;
      final point = LatLng(loc.latitude, loc.longitude);
      if (points.isEmpty || points.last != point) {
        points.add(point);
      }
    }
    return points;
  }

  static List<LatLng> _concatSegments(List<RouteMapSegment> segments) {
    final full = <LatLng>[];
    for (final segment in segments) {
      _appendPolyline(full, segment.points);
    }
    return full;
  }

  static List<LatLng> _snapEndpoints(
    List<LatLng> polyline,
    LatLng origin,
    LatLng destination,
  ) {
    if (polyline.isEmpty) return polyline;

    final result = List<LatLng>.from(polyline);
    result[0] = origin;
    result[result.length - 1] = destination;
    return result;
  }

  static List<LatLng> _pointsForStep(NeshanRouteStep step) {
    if (step.polyline != null && step.polyline!.trim().isNotEmpty) {
      final decoded = decodePolyline(step.polyline!);
      if (decoded.length >= 2) return decoded;
    }
    final loc = step.startLocation;
    if (loc != null) {
      return [LatLng(loc.latitude, loc.longitude)];
    }
    return const [];
  }

  static void _appendPolyline(List<LatLng> target, List<LatLng> chunk) {
    if (chunk.isEmpty) return;
    if (target.isEmpty) {
      target.addAll(chunk);
      return;
    }
    final last = target.last;
    final first = chunk.first;
    if (last.latitude == first.latitude && last.longitude == first.longitude) {
      target.addAll(chunk.skip(1));
    } else {
      target.addAll(chunk);
    }
  }
}

/// Heuristic: only mark clearly jammed segments (not normal urban slowdown).
bool isStepCongested(NeshanRouteStep step) {
  if (step.distanceMeters < 100 || step.durationSeconds <= 0) return false;

  final speedKmh = (step.distanceMeters / step.durationSeconds) * 3.6;
  if (speedKmh < 10) return true;

  const freeFlowMps = 13.9; // ~50 km/h
  final expectedSeconds = step.distanceMeters / freeFlowMps;
  return step.durationSeconds > expectedSeconds * 2.5;
}
