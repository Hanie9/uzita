import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_progress.dart';

/// Minimum step length before we paint traffic on the route line.
const double kMinTrafficStepMeters = 80;

/// Live vs baseline leg distance must be within this share to compare steps.
const double kMaxBaselineDistanceDrift = 0.20;

/// Classifies step traffic for route-line colouring.
///
/// Neshan's routing API bakes live traffic into each step duration but does
/// not return per-segment colours. We only paint a segment when a matching
/// baseline step from the parallel no-traffic / typical route exists and is
/// clearly slower. Otherwise the route stays purple (clear) and the native
/// Neshan traffic layer shows road conditions — like the Neshan Navigator app.
RouteTrafficLevel trafficLevelForStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg liveLeg,
  NeshanRouteLeg? baselineLeg,
  int? stepIndex,
}) {
  if (live.isArrival ||
      live.distanceMeters < kMinTrafficStepMeters ||
      live.durationSeconds <= 0) {
    return RouteTrafficLevel.clear;
  }

  if (baselineLeg == null || !_isComparableBaseline(liveLeg, baselineLeg)) {
    return RouteTrafficLevel.clear;
  }

  final matched = _matchingBaselineStep(
    live,
    baselineLeg: baselineLeg,
    stepIndex: stepIndex,
  );
  if (matched == null || matched.durationSeconds <= 0) {
    return RouteTrafficLevel.clear;
  }

  // Ignore pairs where geometry clearly diverged between the two routes.
  if (matched.distanceMeters > 0 &&
      live.distanceMeters > 0 &&
      (matched.distanceMeters - live.distanceMeters).abs() /
              live.distanceMeters >
          0.45) {
    return RouteTrafficLevel.clear;
  }

  final delayRatio = live.durationSeconds / matched.durationSeconds;
  if (delayRatio >= 2.0) return RouteTrafficLevel.heavy;
  if (delayRatio >= 1.5) return RouteTrafficLevel.moderate;
  return RouteTrafficLevel.clear;
}

bool _isComparableBaseline(NeshanRouteLeg liveLeg, NeshanRouteLeg baselineLeg) {
  if (baselineLeg.durationSeconds <= 0 || liveLeg.distanceMeters <= 0) {
    return false;
  }
  final drift =
      (liveLeg.distanceMeters - baselineLeg.distanceMeters).abs() /
      liveLeg.distanceMeters;
  return drift <= kMaxBaselineDistanceDrift;
}

/// Picks the baseline step that corresponds to [live] — same index first, then
/// nearest [start_location] within 80 m.
NeshanRouteStep? _matchingBaselineStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg baselineLeg,
  int? stepIndex,
}) {
  if (stepIndex != null &&
      stepIndex >= 0 &&
      stepIndex < baselineLeg.steps.length) {
    final atIndex = baselineLeg.steps[stepIndex];
    if (!atIndex.isArrival && atIndex.durationSeconds > 0) {
      return atIndex;
    }
  }

  final loc = live.startLocation;
  if (loc == null) return null;

  final livePoint = LatLng(loc.latitude, loc.longitude);
  NeshanRouteStep? best;
  var bestDist = double.infinity;

  for (final candidate in baselineLeg.steps) {
    if (candidate.isArrival || candidate.startLocation == null) continue;
    final candidatePoint = LatLng(
      candidate.startLocation!.latitude,
      candidate.startLocation!.longitude,
    );
    final dist = distanceMeters(livePoint, candidatePoint);
    if (dist <= 80 && dist < bestDist) {
      bestDist = dist;
      best = candidate;
    }
  }

  return best;
}

bool isStepCongested(
  NeshanRouteStep step, {
  required NeshanRouteLeg liveLeg,
  NeshanRouteLeg? baselineLeg,
  int? stepIndex,
}) =>
    trafficLevelForStep(
      step,
      liveLeg: liveLeg,
      baselineLeg: baselineLeg,
      stepIndex: stepIndex,
    ) ==
    RouteTrafficLevel.heavy;
