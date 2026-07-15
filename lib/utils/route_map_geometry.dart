import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/polyline_decoder.dart';
import 'package:uzita/utils/neshan_traffic_levels.dart';
import 'package:uzita/utils/route_progress.dart';

/// Traffic density along a route segment (kept for API compatibility).
enum RouteTrafficLevel {
  clear,
  smooth,
  moderate,
  heavy;

  static RouteTrafficLevel fromName(String? name) {
    switch (name) {
      case 'heavy':
        return RouteTrafficLevel.heavy;
      case 'moderate':
        return RouteTrafficLevel.moderate;
      case 'smooth':
        return RouteTrafficLevel.smooth;
      default:
        return RouteTrafficLevel.clear;
    }
  }
}

/// A drawable slice of the route with per-step traffic colouring.
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
        : _segmentsFromOverview(route, full);

    return RouteMapGeometry(fullPolyline: full, segments: drawSegments);
  }

  /// Splits [overview] into step-sized slices with traffic colours.
  static List<RouteMapSegment> _segmentsFromOverview(
    NeshanRoute route,
    List<LatLng> overview,
  ) {
    final leg = route.primaryLeg;
    if (leg == null || overview.length < 2 || leg.steps.isEmpty) {
      return overview.length >= 2
          ? [RouteMapSegment(points: overview)]
          : const [];
    }

    final baselineLeg = route.baselineRoute?.primaryLeg;
    final segments = <RouteMapSegment>[];
    var distanceCursor = 0.0;

    for (var stepIndex = 0; stepIndex < leg.steps.length; stepIndex++) {
      final step = leg.steps[stepIndex];
      if (step.isArrival) continue;
      if (step.distanceMeters <= 0 && step.durationSeconds <= 0) continue;

      final stepPoints = step.distanceMeters > 0
          ? slicePolylineByDistance(
              overview,
              distanceCursor,
              step.distanceMeters,
            )
          : const <LatLng>[];
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
    return [RouteMapSegment(points: overview)];
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

    final ahead = polylineAheadOf(fullPolyline, driver);
    if (ahead.length < 2) return segments;

    final merged = <LatLng>[];
    final ranges = <({int start, int end, RouteMapSegment segment})>[];

    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final start = merged.isEmpty ? 0 : merged.length - 1;
      _appendPolyline(merged, segment.points);
      ranges.add((start: start, end: merged.length - 1, segment: segment));
    }

    if (merged.isEmpty) {
      return [
        RouteMapSegment(
          points: ahead,
          trafficLevel: segments.first.trafficLevel,
        ),
      ];
    }

    final startIndex = findClosestPolylineIndex(merged, ahead.first)
        .clamp(0, merged.length - 2);

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

    if (trimmed.isEmpty) {
      return [
        RouteMapSegment(
          points: ahead,
          trafficLevel: segments.first.trafficLevel,
        ),
      ];
    }

    // Snap the first segment to the driver — do not replace it with the full
    // overview polyline (that drew a second road on top of step geometry).
    final snapped = ahead.first;
    final first = trimmed.first;
    final firstPoints = List<LatLng>.from(first.points);
    if (firstPoints.length >= 2) {
      final snapIndex = findClosestPolylineIndex(firstPoints, snapped)
          .clamp(0, firstPoints.length - 2);
      var tail = firstPoints.sublist(snapIndex);
      if (tail.isEmpty) tail = firstPoints;
      if (tail.first.latitude != snapped.latitude ||
          tail.first.longitude != snapped.longitude) {
        tail = [snapped, ...tail];
      }
      trimmed[0] = RouteMapSegment(
        points: tail.length >= 2 ? tail : firstPoints,
        trafficLevel: first.trafficLevel,
      );
    }
    return trimmed;
  }
}

/// Down-samples polyline points for native map channel payloads.
List<LatLng> samplePolylinePoints(
  List<LatLng> points, {
  int maxPoints = 64,
}) {
  if (points.length <= maxPoints) return points;
  if (maxPoints < 2) return points.take(maxPoints).toList();

  final sampled = <LatLng>[points.first];
  final step = (points.length - 1) / (maxPoints - 1);
  for (var i = 1; i < maxPoints - 1; i++) {
    sampled.add(points[(step * i).round()]);
  }
  sampled.add(points.last);
  return sampled;
}

/// Merges adjacent segments and caps count/points for smooth map updates.
///
/// During navigation, keeps more segments/points so per-step traffic colours
/// stay aligned with the Neshan route geometry.
List<RouteMapSegment> compactSegmentsForMap(
  List<RouteMapSegment> segments, {
  int? maxSegments,
  int? maxPointsPerSegment,
  bool navigationMode = false,
}) {
  if (segments.isEmpty) return segments;

  final segmentCap = maxSegments ?? (navigationMode ? 160 : 96);
  final pointCap = maxPointsPerSegment ?? (navigationMode ? 160 : 96);

  final merged = <RouteMapSegment>[];
  for (final segment in segments) {
    if (segment.points.length < 2) continue;
    final points = samplePolylinePoints(
      segment.points,
      maxPoints: pointCap,
    );
    if (points.length < 2) continue;

    if (merged.isNotEmpty &&
        merged.last.trafficLevel == segment.trafficLevel) {
      final prev = merged.last;
      merged[merged.length - 1] = RouteMapSegment(
        points: _concatPolyline(prev.points, points),
        trafficLevel: prev.trafficLevel,
      );
    } else {
      merged.add(
        RouteMapSegment(
          points: points,
          trafficLevel: segment.trafficLevel,
        ),
      );
    }
  }

  var compact = merged;
  while (compact.length > segmentCap && compact.length > 1) {
    var mergedPair = false;
    for (var i = 0; i < compact.length - 1; i++) {
      final a = compact[i];
      final b = compact[i + 1];
      if (a.trafficLevel != b.trafficLevel) continue;
      compact = [
        ...compact.sublist(0, i),
        RouteMapSegment(
          points: _concatPolyline(a.points, b.points),
          trafficLevel: a.trafficLevel,
        ),
        ...compact.sublist(i + 2),
      ];
      mergedPair = true;
      break;
    }
    if (!mergedPair) break;
  }

  return compact;
}

List<LatLng> _concatPolyline(List<LatLng> a, List<LatLng> b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  if (a.last == b.first) return [...a, ...b.skip(1)];
  return [...a, ...b];
}
