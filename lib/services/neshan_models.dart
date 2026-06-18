class NeshanLatLng {
  final double latitude;
  final double longitude;

  const NeshanLatLng({required this.latitude, required this.longitude});

  String get coordinateParam => '$latitude,$longitude';

  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  String toString() => 'NeshanLatLng($latitude, $longitude)';
}

/// Bounding box for geocoding (`extent` in Neshan Geocoding Plus API).
class NeshanGeocodingExtent {
  final NeshanLatLng southWest;
  final NeshanLatLng northEast;

  const NeshanGeocodingExtent({
    required this.southWest,
    required this.northEast,
  });

  Map<String, dynamic> toJson() => {
    'southWest': southWest.toJson(),
    'northEast': northEast.toJson(),
  };
}

class NeshanGeocodingResult {
  final NeshanLatLng location;
  final String? province;
  final String? city;
  final String? neighbourhood;
  final String? unMatchedTerm;
  final String? title;
  final String? formattedAddress;

  /// Up to 5 candidates from Geocoding Plus (best match first).
  final List<NeshanGeocodingCandidate> candidates;

  const NeshanGeocodingResult({
    required this.location,
    this.province,
    this.city,
    this.neighbourhood,
    this.unMatchedTerm,
    this.title,
    this.formattedAddress,
    this.candidates = const [],
  });
}

class NeshanGeocodingCandidate {
  final NeshanLatLng location;
  final String? province;
  final String? city;
  final String? neighbourhood;
  final String? unMatchedTerm;
  final String? title;
  final String? formattedAddress;

  const NeshanGeocodingCandidate({
    required this.location,
    this.province,
    this.city,
    this.neighbourhood,
    this.unMatchedTerm,
    this.title,
    this.formattedAddress,
  });
}

class NeshanRouteStep {
  final String instruction;
  final String name;
  final String distanceText;
  final String durationText;
  final double distanceMeters;
  final double durationSeconds;
  final String? stepType;
  final String? modifier;
  final double? bearingAfter;
  final String? polyline;
  final NeshanLatLng? startLocation;

  const NeshanRouteStep({
    required this.instruction,
    required this.name,
    required this.distanceText,
    required this.durationText,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.stepType,
    this.modifier,
    this.bearingAfter,
    this.polyline,
    this.startLocation,
  });

  bool get isArrival => stepType == 'arrive';
}

class NeshanRouteLeg {
  final String summary;
  final String distanceText;
  final double distanceMeters;
  final String durationText;
  final double durationSeconds;
  final List<NeshanRouteStep> steps;

  const NeshanRouteLeg({
    required this.summary,
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationSeconds,
    required this.steps,
  });
}

class NeshanRoute {
  final List<NeshanRouteLeg> legs;
  final String? overviewPolyline;

  /// Parallel no-traffic route from Neshan [v4/direction/no-traffic].
  final NeshanRoute? baselineRoute;

  const NeshanRoute({
    required this.legs,
    this.overviewPolyline,
    this.baselineRoute,
  });

  NeshanRouteLeg? get primaryLeg => legs.isEmpty ? null : legs.first;

  NeshanRoute withBaseline(NeshanRoute? baseline) {
    if (baseline == null) return this;
    return NeshanRoute(
      legs: legs,
      overviewPolyline: overviewPolyline,
      baselineRoute: baseline,
    );
  }
}
