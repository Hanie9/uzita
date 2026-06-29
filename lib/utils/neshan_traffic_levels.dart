import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_progress.dart';

/// Minimum step length before we paint traffic on the route line.
const double kMinTrafficStepMeters = 25;

/// Matched steps must follow roughly the same geometry.
const double kMaxStepDistanceDrift = 0.55;

const double kMaxStepLocationMismatchMeters = 350;

/// Classifies step traffic by comparing live vs typical (or no-traffic) durations.
RouteTrafficLevel trafficLevelForStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg liveLeg,
  NeshanRouteLeg? baselineLeg,
  int? stepIndex,
}) {
  if (live.isArrival || live.durationSeconds <= 0) {
    return RouteTrafficLevel.clear;
  }

  if (baselineLeg == null || baselineLeg.durationSeconds <= 0) {
    return RouteTrafficLevel.clear;
  }

  final baselineDuration = _baselineDurationForStep(
    live,
    liveLeg: liveLeg,
    baselineLeg: baselineLeg,
    stepIndex: stepIndex,
  );
  if (baselineDuration == null || baselineDuration <= 0) {
    return RouteTrafficLevel.clear;
  }

  if (live.distanceMeters > 0 &&
      live.distanceMeters < kMinTrafficStepMeters &&
      baselineDuration >= live.durationSeconds * 0.95) {
    return RouteTrafficLevel.clear;
  }

  return _trafficLevelFromComparison(
    liveSeconds: live.durationSeconds,
    baselineSeconds: baselineDuration,
    liveLeg: liveLeg,
    baselineLeg: baselineLeg,
    distanceMeters: live.distanceMeters,
  );
}

/// Scales step baseline to the live leg so route-wide traffic does not paint
/// every segment red when comparing live traffic to no-traffic.
double _calibratedBaselineSeconds({
  required double stepBaselineSeconds,
  required NeshanRouteLeg liveLeg,
  required NeshanRouteLeg baselineLeg,
}) {
  if (stepBaselineSeconds <= 0 || baselineLeg.durationSeconds <= 0) {
    return stepBaselineSeconds;
  }
  final legScale = liveLeg.durationSeconds / baselineLeg.durationSeconds;
  return stepBaselineSeconds * legScale;
}

RouteTrafficLevel _trafficLevelFromComparison({
  required double liveSeconds,
  required double baselineSeconds,
  required NeshanRouteLeg liveLeg,
  required NeshanRouteLeg baselineLeg,
  required double distanceMeters,
}) {
  final calibrated = _calibratedBaselineSeconds(
    stepBaselineSeconds: baselineSeconds,
    liveLeg: liveLeg,
    baselineLeg: baselineLeg,
  );
  if (calibrated <= 0) return RouteTrafficLevel.clear;

  final delay = liveSeconds - calibrated;
  final ratio = liveSeconds / calibrated;

  // Short steps are noisy — require a stronger signal.
  if (distanceMeters > 0 && distanceMeters < kMinTrafficStepMeters) {
    if (delay < 12 && ratio < 1.15) return RouteTrafficLevel.clear;
  }

  if (delay >= 55 || ratio >= 1.40) return RouteTrafficLevel.heavy;
  if (delay >= 25 || ratio >= 1.22) return RouteTrafficLevel.moderate;
  if (delay >= 10 || ratio >= 1.10) return RouteTrafficLevel.smooth;
  return RouteTrafficLevel.clear;
}

double? _baselineDurationForStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg liveLeg,
  required NeshanRouteLeg baselineLeg,
  int? stepIndex,
}) {
  final matched = _matchingBaselineStep(
    live,
    liveLeg: liveLeg,
    baselineLeg: baselineLeg,
    stepIndex: stepIndex,
  );
  if (matched != null && matched.durationSeconds > 0) {
    if (live.distanceMeters > 0 && matched.distanceMeters > 0) {
      final drift =
          (matched.distanceMeters - live.distanceMeters).abs() /
          live.distanceMeters;
      if (drift > kMaxStepDistanceDrift) {
        return _proportionalBaselineDuration(live, liveLeg, baselineLeg);
      }
    }
    return matched.durationSeconds;
  }

  return _proportionalBaselineDuration(live, liveLeg, baselineLeg);
}

/// Allocates baseline time by distance share when step pairing fails.
double? _proportionalBaselineDuration(
  NeshanRouteStep live,
  NeshanRouteLeg liveLeg,
  NeshanRouteLeg baselineLeg,
) {
  if (liveLeg.durationSeconds <= 0 || baselineLeg.durationSeconds <= 0) {
    return null;
  }

  if (liveLeg.distanceMeters > 0 &&
      baselineLeg.distanceMeters > 0 &&
      live.distanceMeters > 0) {
    final distanceShare = live.distanceMeters / liveLeg.distanceMeters;
    return baselineLeg.durationSeconds * distanceShare;
  }

  if (liveLeg.durationSeconds > 0 && live.durationSeconds > 0) {
    final timeShare = live.durationSeconds / liveLeg.durationSeconds;
    return baselineLeg.durationSeconds * timeShare;
  }

  return null;
}

double _distanceBeforeStep(NeshanRouteLeg leg, int stepIndex) {
  var offset = 0.0;
  for (var i = 0; i < stepIndex && i < leg.steps.length; i++) {
    final step = leg.steps[i];
    if (step.isArrival) continue;
    offset += step.distanceMeters;
  }
  return offset;
}

/// Picks the baseline step that corresponds to [live].
NeshanRouteStep? _matchingBaselineStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg liveLeg,
  required NeshanRouteLeg baselineLeg,
  int? stepIndex,
}) {
  final sameStepCount = liveLeg.steps.length == baselineLeg.steps.length;

  if (stepIndex != null &&
      stepIndex >= 0 &&
      stepIndex < baselineLeg.steps.length) {
    final atIndex = baselineLeg.steps[stepIndex];
    if (!atIndex.isArrival && atIndex.durationSeconds > 0) {
      final liveLoc = live.startLocation;
      final baseLoc = atIndex.startLocation;
      if (liveLoc != null && baseLoc != null) {
        final dist = distanceMeters(
          LatLng(liveLoc.latitude, liveLoc.longitude),
          LatLng(baseLoc.latitude, baseLoc.longitude),
        );
        if (dist <= kMaxStepLocationMismatchMeters) return atIndex;
      } else if (sameStepCount) {
        return atIndex;
      }
    }
  }

  final loc = live.startLocation;
  if (loc != null) {
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
      if (dist <= kMaxStepLocationMismatchMeters && dist < bestDist) {
        bestDist = dist;
        best = candidate;
      }
    }
    if (best != null) return best;
  }

  if (stepIndex != null && stepIndex >= 0) {
    return _baselineStepAtDistance(
      baselineLeg,
      _distanceBeforeStep(liveLeg, stepIndex) + live.distanceMeters / 2,
    );
  }

  return null;
}

NeshanRouteStep? _baselineStepAtDistance(
  NeshanRouteLeg baselineLeg,
  double distanceAlong,
) {
  if (baselineLeg.steps.isEmpty) return null;

  var cursor = 0.0;
  NeshanRouteStep? last;
  for (final step in baselineLeg.steps) {
    if (step.isArrival) continue;
    last = step;
    final span = step.distanceMeters > 0 ? step.distanceMeters : 0.0;
    if (distanceAlong <= cursor + span) return step;
    cursor += span;
  }
  return last;
}

RouteTrafficLevel mergeTrafficLevels(
  RouteTrafficLevel a,
  RouteTrafficLevel b,
) {
  if (a == RouteTrafficLevel.heavy || b == RouteTrafficLevel.heavy) {
    return RouteTrafficLevel.heavy;
  }
  if (a == RouteTrafficLevel.moderate || b == RouteTrafficLevel.moderate) {
    return RouteTrafficLevel.moderate;
  }
  if (a == RouteTrafficLevel.smooth || b == RouteTrafficLevel.smooth) {
    return RouteTrafficLevel.smooth;
  }
  return RouteTrafficLevel.clear;
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
