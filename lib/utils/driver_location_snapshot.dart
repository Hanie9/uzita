import 'package:latlong2/latlong.dart';

/// GPS update for live driver tracking on the map.
class DriverLocationSnapshot {
  final LatLng position;

  /// Degrees clockwise from north. Null when device heading is unavailable.
  final double? heading;

  final double speedMps;

  const DriverLocationSnapshot({
    required this.position,
    this.heading,
    this.speedMps = 0,
  });

  bool get hasHeading => heading != null;
}
