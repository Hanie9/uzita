import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/neshan_traffic_levels.dart';
import 'package:uzita/utils/polyline_decoder.dart';
import 'package:uzita/utils/route_progress.dart';

/// Traffic density along a route segment.
enum RouteTrafficLevel {
  clear,
  moderate,
  heavy;

  static RouteTrafficLevel fromName(String? name) {
    switch (name) {
      case 'heavy':
        return RouteTrafficLevel.heavy;
      case 'moderate':
        return RouteTrafficLevel.moderate;
      default:
        return RouteTrafficLevel.clear;
    }
  }
}

/// A drawable slice of the route (blue = clear, orange = moderate, red = heavy).
class RouteMapSegment {
  final List<LatLng> points;
  final RouteTrafficLevel trafficLevel;

  const RouteMapSegment({
    required this.points,
    this.trafficLevel = RouteTrafficLevel.clear,
  });

  bool get congested => trafficLevel == RouteTrafficLevel.heavy;
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
          RouteMapSegment(points: full),
        ],
      );
    }

    full = _snapEndpoints(full, origin, destination);

    final drawSegments = segments.isNotEmpty
        ? segments
        : [RouteMapSegment(points: full)];

    return RouteMapGeometry(fullPolyline: full, segments: drawSegments);
  }

  static List<LatLng> _decodeOverview(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const [];
    return decodePolyline(encoded);
  }

  static List<RouteMapSegment> _buildStepSegments(NeshanRoute route) {
    final leg = route.primaryLeg;
    if (leg == null || leg.steps.isEmpty) return const [];

    final baselineLeg = route.baselineRoute?.primaryLeg;
    final overview = _decodeOverview(route.overviewPolyline);
    final segments = <RouteMapSegment>[];
    var distanceCursor = 0.0;

    for (var stepIndex = 0; stepIndex < leg.steps.length; stepIndex++) {
      final step = leg.steps[stepIndex];
      if (step.isArrival) continue;
      if (step.distanceMeters <= 0 && step.durationSeconds <= 0) continue;

      var stepPoints = _pointsForStep(step);
      if (stepPoints.length < 2 && overview.length >= 2 && step.distanceMeters > 0) {
        stepPoints = slicePolylineByDistance(
          overview,
          distanceCursor,
          step.distanceMeters,
        );
      }
      distanceCursor += step.distanceMeters;

      if (stepPoints.length < 2) continue;

      segments.add(
        RouteMapSegment(
          points: stepPoints,
          trafficLevel: trafficLevelForStep(
            step,
            liveLeg: leg,
            baselineLeg: baselineLeg,
            stepIndex: stepIndex,
          ),
        ),
      );
    }

    if (segments.isNotEmpty) return segments;

    final linked = _polylineFromStepLocations(route);
    if (linked.length >= 2) {
      return [RouteMapSegment(points: linked)];
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

  /// Keeps only the route ahead of the driver while preserving per-segment traffic.
  static List<RouteMapSegment> trimSegmentsFromDriver({
    required List<RouteMapSegment> segments,
    required List<LatLng> fullPolyline,
    required LatLng driver,
  }) {
    if (segments.isEmpty || fullPolyline.length < 2) return segments;

    final startIndex = findClosestPolylineIndex(fullPolyline, driver)
        .clamp(0, fullPolyline.length - 2);

    final merged = <LatLng>[];
    final ranges = <({int start, int end, RouteMapSegment segment})>[];

    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final start = merged.isEmpty ? 0 : merged.length - 1;
      _appendPolyline(merged, segment.points);
      ranges.add((start: start, end: merged.length - 1, segment: segment));
    }

    if (merged.isEmpty) return segments;

    final trimmed = <RouteMapSegment>[];
    for (final range in ranges) {
      if (range.end < startIndex) continue;

      var localStart = 0;
      if (range.start < startIndex) {
        localStart =
            (startIndex - range.start).clamp(0, range.segment.points.length - 2);
      }

      final points = range.segment.points.sublist(localStart);
      if (points.length >= 2) {
        trimmed.add(
          RouteMapSegment(
            points: points,
            trafficLevel: range.segment.trafficLevel,
          ),
        );
      }
    }

    return trimmed.isNotEmpty ? trimmed : segments;
  }
}
