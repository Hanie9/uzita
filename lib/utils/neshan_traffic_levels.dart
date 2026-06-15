import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_map_geometry.dart';

/// Classifies step traffic.
///
/// The public Neshan routing API does NOT return per-segment traffic data, so
/// exact map-matching with Neshan's traffic layer is not possible. When a
/// no-traffic [baselineLeg] is available (account subscribed to the Neshan
/// no-traffic service) we compare live vs baseline duration — this matches
/// Neshan's congestion signal. Otherwise we only flag *genuine* congestion by
/// absolute speed, so normally-slow urban roads are not painted as traffic.
RouteTrafficLevel trafficLevelForStep(
  NeshanRouteStep live, {
  required NeshanRouteLeg liveLeg,
  NeshanRouteLeg? baselineLeg,
}) {
  if (live.isArrival || live.distanceMeters < 40 || live.durationSeconds <= 0) {
    return RouteTrafficLevel.clear;
  }

  // Preferred: compare against a real no-traffic baseline.
  if (baselineLeg != null && baselineLeg.durationSeconds > 0) {
    final expectedSeconds = _baselineSecondsForStep(
      live,
      liveLeg: liveLeg,
      baselineLeg: baselineLeg,
    );
    if (expectedSeconds > 0) {
      final delayRatio = live.durationSeconds / expectedSeconds;
      if (delayRatio >= 1.5) return RouteTrafficLevel.heavy;
      if (delayRatio >= 1.2) return RouteTrafficLevel.moderate;
      return RouteTrafficLevel.clear;
    }
  }

  // No baseline: flag only real congestion (stop-and-go / jams) by absolute
  // speed. Free-flowing or normally-slow roads stay clear.
  final speedKmh = (live.distanceMeters / live.durationSeconds) * 3.6;
  if (speedKmh < 12) return RouteTrafficLevel.heavy;
  if (speedKmh < 22) return RouteTrafficLevel.moderate;
  return RouteTrafficLevel.clear;
}

double _baselineSecondsForStep(
  NeshanRouteStep step, {
  required NeshanRouteLeg liveLeg,
  required NeshanRouteLeg baselineLeg,
}) {
  if (liveLeg.distanceMeters > 0 && step.distanceMeters > 0) {
    final share = step.distanceMeters / liveLeg.distanceMeters;
    return (share * baselineLeg.durationSeconds).clamp(4.0, double.infinity);
  }
  return 0;
}

bool isStepCongested(
  NeshanRouteStep step, {
  required NeshanRouteLeg liveLeg,
  NeshanRouteLeg? baselineLeg,
}) =>
    trafficLevelForStep(
      step,
      liveLeg: liveLeg,
      baselineLeg: baselineLeg,
    ) ==
    RouteTrafficLevel.heavy;
