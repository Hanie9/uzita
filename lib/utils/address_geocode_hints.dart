import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_progress.dart';

/// Minimum score before treating a Search POI lookup as confidently matched.
const int kMinGeocodingMatchScore = 4;

/// City/province hints parsed from free-text Persian addresses.
class AddressGeocodeHints {
  final String? city;
  final String? province;

  const AddressGeocodeHints({this.city, this.province});
}

/// Approximate center of major cities for geocoding bias (lat, lng).
const Map<String, NeshanLatLng> iranCityCentroids = {
  'تهران': NeshanLatLng(latitude: 35.6892, longitude: 51.3890),
  'اصفهان': NeshanLatLng(latitude: 32.6539, longitude: 51.6660),
  'مشهد': NeshanLatLng(latitude: 36.2970, longitude: 59.6062),
  'شیراز': NeshanLatLng(latitude: 29.5918, longitude: 52.5837),
  'تبریز': NeshanLatLng(latitude: 38.0800, longitude: 46.2919),
  'کرج': NeshanLatLng(latitude: 35.8400, longitude: 50.9391),
  'اهواز': NeshanLatLng(latitude: 31.3183, longitude: 48.6706),
  'قم': NeshanLatLng(latitude: 34.6416, longitude: 50.8746),
  'کرمانشاه': NeshanLatLng(latitude: 34.3142, longitude: 47.0650),
  'رشت': NeshanLatLng(latitude: 37.2808, longitude: 49.5832),
  'یزد': NeshanLatLng(latitude: 31.8974, longitude: 54.3569),
  'کرمان': NeshanLatLng(latitude: 30.2839, longitude: 57.0834),
  'اراک': NeshanLatLng(latitude: 34.0917, longitude: 49.6892),
  'ارومیه': NeshanLatLng(latitude: 37.5527, longitude: 45.0761),
  'زاهدان': NeshanLatLng(latitude: 29.4963, longitude: 60.8629),
  'همدان': NeshanLatLng(latitude: 34.7992, longitude: 48.5146),
  'قزوین': NeshanLatLng(latitude: 36.2688, longitude: 50.0041),
  'ساری': NeshanLatLng(latitude: 36.5633, longitude: 53.0601),
  'بندرعباس': NeshanLatLng(latitude: 27.1865, longitude: 56.2808),
  'بندر عباس': NeshanLatLng(latitude: 27.1865, longitude: 56.2808),
  'گرگان': NeshanLatLng(latitude: 36.8416, longitude: 54.4436),
  'سنندج': NeshanLatLng(latitude: 35.3219, longitude: 46.9862),
  'خرم‌آباد': NeshanLatLng(latitude: 33.4878, longitude: 48.3558),
  'خرم اباد': NeshanLatLng(latitude: 33.4878, longitude: 48.3558),
  'بوشهر': NeshanLatLng(latitude: 28.9234, longitude: 50.8203),
  'ایلام': NeshanLatLng(latitude: 33.6374, longitude: 46.4227),
  'بیرجند': NeshanLatLng(latitude: 32.8663, longitude: 59.2211),
  'شهرکرد': NeshanLatLng(latitude: 32.3256, longitude: 50.8644),
  'یاسوج': NeshanLatLng(latitude: 30.6682, longitude: 51.5870),
  'سمنان': NeshanLatLng(latitude: 35.5729, longitude: 53.3971),
  'کاشان': NeshanLatLng(latitude: 34.0100, longitude: 51.3650),
};

/// Major Iranian cities for hint extraction from address text.
const _iranCities = <String, String>{
  'تهران': 'تهران',
  'اصفهان': 'اصفهان',
  'مشهد': 'خراسان رضوی',
  'شیراز': 'فارس',
  'تبریز': 'آذربایجان شرقی',
  'کرج': 'البرز',
  'اهواز': 'خوزستان',
  'قم': 'قم',
  'کرمانشاه': 'کرمانشاه',
  'رشت': 'گیلان',
  'یزد': 'یزد',
  'کرمان': 'کرمان',
  'اراک': 'مرکزی',
  'ارومیه': 'آذربایجان غربی',
  'زاهدان': 'سیستان و بلوچستان',
  'همدان': 'همدان',
  'قزوین': 'قزوین',
  'ساری': 'مازندران',
  'بندرعباس': 'هرمزگان',
  'بندر عباس': 'هرمزگان',
  'گرگان': 'گلستان',
  'سنندج': 'کردستان',
  'خرم‌آباد': 'لرستان',
  'خرم اباد': 'لرستان',
  'بوشهر': 'بوشهر',
  'ایلام': 'ایلام',
  'بیرجند': 'خراسان جنوبی',
  'شهرکرد': 'چهارمحال و بختیاری',
  'یاسوج': 'کهگیلویه و بویراحمد',
  'سمنان': 'سمنان',
  'کاشان': 'اصفهان',
};

AddressGeocodeHints extractGeocodeHints(String address) {
  final normalized = _normalizeAddress(address);

  // Longer city names first (e.g. "بندر عباس" before partial matches).
  final entries = _iranCities.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

  for (final entry in entries) {
    if (normalized.contains(entry.key)) {
      return AddressGeocodeHints(city: entry.key, province: entry.value);
    }
  }

  return const AddressGeocodeHints();
}

String normalizeGeocodeAddress(String address) {
  return address
      .replaceAll('\u200c', ' ')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('  ', ' ')
      .trim();
}

String _normalizeAddress(String address) => normalizeGeocodeAddress(address);

/// Build geocoding API parameters — never bias destination to a different city.
({
  String? city,
  String? province,
  NeshanLatLng? searchCenter,
  NeshanGeocodingExtent? searchExtent,
}) buildGeocodeParams({
  required String address,
  required AddressGeocodeHints hints,
  NeshanGeocodingResult? originResult,
  NeshanLatLng? driverLocation,
}) {
  final city = hints.city;
  final province = hints.province;

  if (city != null) {
    final centroid = iranCityCentroids[city];
    if (centroid != null) {
      final center = driverLocation != null &&
              _isNearCity(driverLocation, city)
          ? driverLocation
          : centroid;
      final radiusKm = center == driverLocation ? 35.0 : 55.0;
      return (
        city: city,
        province: province,
        searchCenter: center,
        searchExtent: geocodeExtentAround(center, radiusKm: radiusKm),
      );
    }
    return (city: city, province: province, searchCenter: null, searchExtent: null);
  }

  // No city in address — only bias near origin when origin is in the same city.
  final originCity = originResult?.city?.trim();
  if (originResult != null &&
      originCity != null &&
      originCity.isNotEmpty &&
      _normalizeAddress(address).contains(originCity)) {
    return (
      city: originCity,
      province: originResult.province,
      searchCenter: originResult.location,
      searchExtent: geocodeExtentAround(originResult.location, radiusKm: 40),
    );
  }

  if (driverLocation != null && isPlausibleIranCoordinate(driverLocation)) {
    return (
      city: null,
      province: null,
      searchCenter: driverLocation,
      searchExtent: geocodeExtentAround(driverLocation, radiusKm: 80),
    );
  }

  return (city: null, province: null, searchCenter: null, searchExtent: null);
}

/// Cargo endpoints (mabda/maghsad): bias to city or sibling origin only — never
/// driver GPS, which pulls unrelated addresses toward the driver.
({
  String? city,
  String? province,
  NeshanLatLng? searchCenter,
  NeshanGeocodingExtent? searchExtent,
}) buildCargoGeocodeParams({
  required String address,
  required AddressGeocodeHints hints,
  NeshanGeocodingResult? siblingResult,
}) {
  final city = hints.city;
  final province = hints.province;

  if (city != null) {
    final centroid = iranCityCentroids[city];
    if (centroid != null) {
      // Geocoding Plus snaps POIs (metro stations, squares, …) to the city
      // centre when `location`/`extent` bias is sent — only pass city/province.
      if (isPoiAddress(address)) {
        return (
          city: city,
          province: province,
          searchCenter: null,
          searchExtent: null,
        );
      }
      final radiusKm = hasSpecificLocationTerms(address) ? 42.0 : 65.0;
      return (
        city: city,
        province: province,
        searchCenter: centroid,
        searchExtent: geocodeExtentAround(centroid, radiusKm: radiusKm),
      );
    }
    return (city: city, province: province, searchCenter: null, searchExtent: null);
  }

  final originCity = siblingResult?.city?.trim();
  if (siblingResult != null &&
      originCity != null &&
      originCity.isNotEmpty &&
      !isPoiAddress(address) &&
      _normalizeAddress(address).contains(originCity)) {
    return (
      city: originCity,
      province: siblingResult.province,
      searchCenter: siblingResult.location,
      searchExtent: geocodeExtentAround(siblingResult.location, radiusKm: 45),
    );
  }

  return (city: null, province: null, searchCenter: null, searchExtent: null);
}

/// True when the address names a street, plate, POI, etc. (not just city).
bool hasSpecificLocationTerms(String address) {
  if (isPoiAddress(address)) return true;
  const markers = [
    'خیابان',
    'کوچه',
    'بلوار',
    'بزرگراه',
    'اتوبان',
    'جاده',
    'پلاک',
    'نبش',
    'روبروی',
    'جنب',
    'نرسیده',
    'بعد از',
    'پل ',
  ];
  final normalized = _normalizeAddress(address);
  return markers.any(normalized.contains);
}

/// Geocoding Plus «full match» snapped to the city centre while the address
/// names a specific place elsewhere in the metro area.
bool isCityCentreGeocodingSnap(
  NeshanGeocodingResult result,
  String address,
) {
  if (!hasSpecificLocationTerms(address)) return false;
  if (!isNearCityCentroid(result, address)) return false;

  final hints = extractGeocodeHints(address);
  final query = extractGeocodeQuery(address, hints: hints);
  final terms = _significantTerms(query.isNotEmpty ? query : address);
  if (_resultOverlapsAddressTerms(result, terms)) return false;

  if (!geocodedCityMatchesAddress(result: result, address: address)) return true;
  if (isPoiAddress(address)) return true;
  // Same-city street at centre with no metadata overlap — likely wrong snap.
  const streetMarkers = ['خیابان', 'کوچه', 'بلوار', 'بزرگراه'];
  return streetMarkers.any(_normalizeAddress(address).contains);
}

/// First five digits of a ten-digit Iranian postal code (گشت کدپستی).
String? extractPostalCodeGush(String address) {
  final match = RegExp(r'\d{10}').firstMatch(_normalizeAddress(address));
  if (match == null) return null;
  return match.group(0)!.substring(0, 5);
}

/// Address payload for Geocoding Plus — keeps postal gush when present.
String geocodeApiAddressText(String address) {
  final normalized = normalizeGeocodeAddress(address);
  final gush = extractPostalCodeGush(normalized);
  if (gush == null || normalized.contains(gush)) return normalized;
  return '$normalized $gush';
}

/// Address text sent to geocoding/search APIs — city prefix removed so POI
/// names such as «دانشگاه کاشان» are resolved instead of the city centre.
String extractGeocodeQuery(
  String address, {
  AddressGeocodeHints? hints,
}) {
  final resolvedHints = hints ?? extractGeocodeHints(address);
  var normalized = _normalizeAddress(address);

  if (resolvedHints.city != null) {
    final city = RegExp.escape(resolvedHints.city!);
    normalized = normalized
        .replaceFirst(RegExp('^$city\\s*[,،\\-–]\\s*'), '')
        .trim();
  }

  return normalized;
}

/// Search/geocode query variants — mirrors how users type addresses in Neshan.
List<String> buildGeocodeSearchTerms(
  String address, {
  AddressGeocodeHints? hints,
}) {
  final resolvedHints = hints ?? extractGeocodeHints(address);
  final normalized = _normalizeAddress(address);
  final query = extractGeocodeQuery(address, hints: resolvedHints);
  final terms = <String>[];

  void add(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == '---') return;
    if (!terms.contains(trimmed)) terms.add(trimmed);
  }

  // Geocoding Plus: full text first (province/city also sent as API filters).
  add(normalized);
  add(query);
  if (resolvedHints.city != null && query.isNotEmpty) {
    add('${resolvedHints.city}، $query');
  }

  for (final extra in buildGeocodePlusExtraTerms(address, hints: resolvedHints)) {
    add(extra);
  }

  return terms;
}

/// Extra Geocoding Plus queries for POIs when Search API is unavailable.
List<String> buildGeocodePlusExtraTerms(
  String address, {
  AddressGeocodeHints? hints,
}) {
  final resolvedHints = hints ?? extractGeocodeHints(address);
  final query = extractGeocodeQuery(address, hints: resolvedHints);
  if (query.isEmpty || !isPoiAddress(address)) return const [];

  final extras = <String>[];

  void add(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == '---') return;
    if (!extras.contains(trimmed)) extras.add(trimmed);
  }

  for (final match in RegExp(r'میدان\s+\S+').allMatches(query)) {
    add(match.group(0));
  }

  final metroMatch = RegExp(r'ایستگاه\s+مترو\s+(.+)$').firstMatch(query);
  if (metroMatch != null) {
    final station = metroMatch.group(1)?.trim();
    if (station != null && station.isNotEmpty) {
      add(station);
      add('مترو $station');
      add('ایستگاه $station');
    }
  }

  const prefixes = [
    'ایستگاه مترو ',
    'ایستگاه اتوبوس ',
    'ایستگاه ',
    'مترو ',
  ];
  var stripped = query;
  for (final prefix in prefixes) {
    if (stripped.startsWith(prefix)) {
      add(stripped.substring(prefix.length).trim());
      stripped = stripped.substring(prefix.length).trim();
    }
  }

  for (final term in _significantTerms(query)) {
    if (term.length >= 4) add(term);
  }

  if (resolvedHints.city != null) {
    for (final extra in List<String>.from(extras)) {
      add('${resolvedHints.city}، $extra');
    }
  }

  return extras;
}

/// True when the address names a landmark POI, not just a street or neighbourhood.
bool isPoiAddress(String address) {
  final hints = extractGeocodeHints(address);
  final query = extractGeocodeQuery(address, hints: hints);
  if (query.length < 4) return false;
  if (hints.city != null &&
      _normalizeCityName(query) == _normalizeCityName(hints.city!)) {
    return false;
  }

  const poiKeywords = [
    'میدان',
    'دانشگاه',
    'بیمارستان',
    'فرودگاه',
    'ایستگاه',
    'پارک علم',
    'پارک',
    'مجتمع',
    'پردیس',
    'رصدخانه',
    'مدرسه',
    'بازار',
    'پایانه',
    'ترمینال',
    'مترو',
    'مسجد جامع',
    'حوزه',
  ];

  const streetMarkers = [
    'خیابان',
    'کوچه',
    'بلوار',
    'بزرگراه',
    'اتوبان',
    'جاده',
  ];

  final normalized = _normalizeAddress(query);
  if (streetMarkers.any(normalized.contains)) return false;
  return poiKeywords.any(normalized.contains);
}

/// How well [result] matches the user-entered [address] (higher is better).
int geocodingMatchScore(NeshanGeocodingResult result, String address) {
  final hints = extractGeocodeHints(address);
  final query = extractGeocodeQuery(address, hints: hints);
  final terms = _significantTerms(query.isNotEmpty ? query : address);
  if (terms.isEmpty) return 6;

  final searchable = _normalizeAddress(
    [
      result.title,
      result.formattedAddress,
      result.neighbourhood,
      result.city,
    ].whereType<String>().join(' '),
  );

  var score = 0;
  for (final term in terms) {
    if (searchable.contains(term)) {
      score += 10;
    } else if (searchable.split(' ').any(
      (word) => word.length >= 3 && (word.contains(term) || term.contains(word)),
    )) {
      score += 5;
    }
  }

  if (terms.isNotEmpty && score == 0) {
    score -= 6;
  }

  if (hints.city != null) {
    final expected = _normalizeCityName(hints.city!);
    final actual = _normalizeCityName(result.city ?? '');
    if (actual == expected ||
        actual.contains(expected) ||
        expected.contains(actual)) {
      score += 4;
    } else {
      score -= 6;
    }
  }

  final unmatched = (result.unMatchedTerm ?? '').trim();
  if (unmatched.isEmpty) {
    score += 3;
  } else if (terms.isNotEmpty && score < 8) {
    score -= 5;
  }

  if (result.title != null && result.title!.trim().isNotEmpty) {
    score += isPoiAddress(address) ? 5 : 2;
    final title = _normalizeAddress(result.title!);
    for (final term in terms) {
      if (title.contains(term)) {
        score += 6;
        break;
      }
    }
  }

  return score;
}

List<String> _significantTerms(String text) {
  final normalized = _normalizeAddress(text);
  final terms = <String>[];

  // Keep compound POI phrases such as «میدان فردوسی».
  for (final match in RegExp(r'میدان\s+\S+').allMatches(normalized)) {
    final phrase = match.group(0)?.trim();
    if (phrase != null && phrase.length >= 4) terms.add(phrase);
  }

  final raw = normalized.split(RegExp(r'[,،\-–\s]+'));
  for (final part in raw) {
    final term = part.trim();
    if (term.length < 3) continue;
    if (_isGenericAddressWord(term)) continue;
    if (_isCityName(term)) continue;
    if (!terms.contains(term)) terms.add(term);
  }
  return terms;
}

bool _isCityName(String word) {
  return _iranCities.containsKey(word) || iranCityCentroids.containsKey(word);
}

bool _isNearCity(NeshanLatLng point, String city) {
  final centroid = iranCityCentroids[city];
  if (centroid == null) return false;
  return distanceMeters(
    LatLng(point.latitude, point.longitude),
    LatLng(centroid.latitude, centroid.longitude),
  ) <= 120000;
}

/// Coordinates where Neshan Geocoding Plus often snaps unrelated queries.
const List<({NeshanLatLng location, double radiusMeters})>
    kNeshanFalsePositiveLocations = [
  // Neshan often snaps unrelated Tehran queries to the defense universities.
  (
    location: NeshanLatLng(latitude: 35.7443, longitude: 51.1952),
    radiusMeters: 3500,
  ),
];

/// True when the user address explicitly targets the defense-university POI.
bool addressMentionsDefenseUniversityPoi(String address) {
  final normalized = _normalizeAddress(address);
  const markers = [
    'دانشگاه علوم و فنون',
    'علوم و فنون فرماندهی',
    'دانشگاه فرماندهی',
    'فرماندهی و ستاد آجا',
    'علوم دفاعی',
    'دانشگاه دفاع',
    'دانشگاه علوم دفاعی',
  ];
  return markers.any(normalized.contains);
}

bool addressMentionsWarUniversityPoi(String address) {
  return _normalizeAddress(address).contains('دانشگاه جنگ');
}

/// Neshan often returns this POI for unrelated Tehran addresses (e.g. «ستاد»).
bool isKnownNeshanFalsePositiveLocation(
  NeshanGeocodingResult result,
  String address,
) {
  if (addressMentionsDefenseUniversityPoi(address) ||
      addressMentionsWarUniversityPoi(address)) {
    return false;
  }

  final point = LatLng(result.location.latitude, result.location.longitude);
  for (final spot in kNeshanFalsePositiveLocations) {
    final dist = distanceMeters(
      point,
      LatLng(spot.location.latitude, spot.location.longitude),
    );
    if (dist <= spot.radiusMeters) return true;
  }
  return false;
}

/// Known Neshan Search false positives when the query is unrelated.
bool isSpuriousDefaultSearchPoi(
  NeshanGeocodingResult result,
  String address,
) {
  if (isKnownNeshanFalsePositiveLocation(result, address)) return true;

  final label = _normalizeAddress(
    [
      result.title,
      result.formattedAddress,
      result.neighbourhood,
    ].whereType<String>().join(' '),
  );

  const spuriousPatterns = [
    'دانشگاه جنگ',
    'دانشگاه فرماندهی',
    'علوم و فنون',
    'فرماندهی و ستاد',
    'دانشگاه دفاع',
    'علوم دفاعی',
  ];
  final isSpuriousPlace =
      spuriousPatterns.any((pattern) => label.contains(pattern));
  if (!isSpuriousPlace) return false;

  if (addressMentionsDefenseUniversityPoi(address)) return false;
  if (addressMentionsWarUniversityPoi(address)) return false;

  // Never accept these default POIs unless the address names them explicitly.
  return true;
}

bool _isGenericAddressWord(String word) {
  const generic = {
    'خیابان',
    'کوچه',
    'بلوار',
    'میدان',
    'بن بست',
    'جاده',
    'اتوبان',
    'بزرگراه',
    'پلاک',
    'واحد',
    'طبقه',
    'ایران',
    'ایستگاه',
    'مترو',
  };
  return generic.contains(word);
}

/// Pick the Geocoding Plus candidate that best matches [address].
NeshanGeocodingCandidate pickBestGeocodingCandidate(
  List<NeshanGeocodingCandidate> candidates,
  String address, {
  NeshanLatLng? searchCenter,
}) {
  if (candidates.isEmpty) {
    throw ArgumentError('candidates must not be empty');
  }

  final viable = <NeshanGeocodingCandidate>[];
  for (final candidate in candidates) {
    final probe = NeshanGeocodingResult(
      location: candidate.location,
      province: candidate.province,
      city: candidate.city,
      neighbourhood: candidate.neighbourhood,
      unMatchedTerm: candidate.unMatchedTerm,
      title: candidate.title,
      formattedAddress: candidate.formattedAddress,
    );
    if (!isHardRejectGeocodingResult(probe, address)) {
      viable.add(candidate);
    }
  }

  if (viable.isEmpty) {
    throw ArgumentError('No viable geocoding candidates for address');
  }

  final pool = viable;
  if (pool.length == 1) return pool.first;

  final hints = extractGeocodeHints(address);
  final expectedCity = hints.city != null ? _normalizeCityName(hints.city!) : null;

  NeshanGeocodingCandidate? best;
  var bestScore = -1000;

  for (var i = 0; i < pool.length; i++) {
    final candidate = pool[i];
    // Neshan returns up to 5 items ordered by relevance — prefer earlier ranks.
    final apiRankBonus = (pool.length - i) * 2;
    final score = _candidateMatchScore(
      candidate,
      address: address,
      expectedCity: expectedCity,
      searchCenter: searchCenter,
    ) +
        apiRankBonus;
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  return best ?? pool.first;
}

/// Pick the candidate that best matches the expected city and POI terms.
NeshanGeocodingResult refineGeocodingResult(
  NeshanGeocodingResult result, {
  required String address,
  NeshanLatLng? searchCenter,
}) {
  if (result.candidates.isEmpty) return result;

  final best = pickBestGeocodingCandidate(
    result.candidates,
    address,
    searchCenter: searchCenter,
  );
  return NeshanGeocodingResult(
    location: best.location,
    province: best.province,
    city: best.city,
    neighbourhood: best.neighbourhood,
    unMatchedTerm: best.unMatchedTerm,
    title: best.title,
    formattedAddress: best.formattedAddress,
    candidates: result.candidates,
  );
}

int _candidateMatchScore(
  NeshanGeocodingCandidate candidate, {
  required String address,
  required String? expectedCity,
  NeshanLatLng? searchCenter,
}) {
  final result = NeshanGeocodingResult(
    location: candidate.location,
    province: candidate.province,
    city: candidate.city,
    neighbourhood: candidate.neighbourhood,
    unMatchedTerm: candidate.unMatchedTerm,
    title: candidate.title,
    formattedAddress: candidate.formattedAddress,
  );
  var score = geocodingMatchScore(result, address);

  if (expectedCity != null) {
    score += _candidateCityScore(candidate, expectedCity) * 2;
  }

  final unmatched = (candidate.unMatchedTerm ?? '').trim();
  final relates = resultMatchesAddressTerms(result, address);
  if (unmatched.isEmpty) {
    if (relates) {
      score += 18;
    } else if (geocodedCityMatchesAddress(result: result, address: address)) {
      score += 10;
    } else {
      score -= 8;
    }
  } else {
    score -= unmatched.length.clamp(0, 20);
  }

  if (searchCenter != null) {
    final dist = distanceMeters(
      LatLng(candidate.location.latitude, candidate.location.longitude),
      LatLng(searchCenter.latitude, searchCenter.longitude),
    );
    if (dist <= 8000) {
      score += 12;
    } else if (dist <= 25000) {
      score += 5;
    } else if (dist >= 55000) {
      score -= 14;
    }
  }

  return score;
}

/// Max distance (m) a geocoded point may be from the search bias for [address].
double geocodeMaxBiasMeters(String address, NeshanLatLng bias) {
  final hints = extractGeocodeHints(address);
  if (hints.city != null) {
    final centroid = iranCityCentroids[hints.city];
    if (centroid != null) {
      // Cargo endpoints may be anywhere in the metro area, not near driver GPS.
      return 75000;
    }
  }
  return 150000;
}

/// True when [result] sits in the expected metro area for [address].
bool isGeocodeWithinBias(
  NeshanGeocodingResult result, {
  required String address,
  NeshanLatLng? bias,
}) {
  if (!isPlausibleIranCoordinate(result.location)) return false;

  final hints = extractGeocodeHints(address);
  if (hints.city != null) {
    final centroid = iranCityCentroids[hints.city];
    if (centroid != null) {
      final distFromCity = distanceMeters(
        LatLng(result.location.latitude, result.location.longitude),
        LatLng(centroid.latitude, centroid.longitude),
      );
      if (distFromCity <= geocodeMaxBiasMeters(address, centroid)) {
        return true;
      }
    }
  }

  if (bias == null) return true;
  final dist = distanceMeters(
    LatLng(result.location.latitude, result.location.longitude),
    LatLng(bias.latitude, bias.longitude),
  );
  return dist <= geocodeMaxBiasMeters(address, bias);
}

/// Geocoding Plus returned a full match (per Neshan docs).
bool isGeocodingPlusFullMatch(NeshanGeocodingResult result) {
  final unmatched = (result.unMatchedTerm ?? '').trim();
  final hasTitle = result.title != null && result.title!.trim().isNotEmpty;
  return unmatched.isEmpty && !hasTitle;
}

int _candidateCityScore(
  NeshanGeocodingCandidate candidate,
  String normalizedExpected,
) {
  final candidateCity = _normalizeCityName(candidate.city ?? '');
  if (candidateCity.isEmpty) return 0;

  if (candidateCity == normalizedExpected) return 4;
  if (candidateCity.contains(normalizedExpected) ||
      normalizedExpected.contains(candidateCity)) {
    return 3;
  }

  final unmatched = (candidate.unMatchedTerm ?? '').trim().length;
  return unmatched == 0 ? 1 : 0;
}

String _normalizeCityName(String city) {
  return _normalizeAddress(city)
      .replaceAll('شهر ', '')
      .replaceAll('شهرستان ', '')
      .trim();
}

bool geocodedCityMatchesAddress({
  required NeshanGeocodingResult result,
  required String address,
}) {
  final hints = extractGeocodeHints(address);
  final expected = hints.city;
  if (expected == null) return true;

  final actual = result.city ?? '';
  final normExpected = _normalizeCityName(expected);
  final normActual = _normalizeCityName(actual);

  if (normActual.isEmpty) return true;
  return normActual == normExpected ||
      normActual.contains(normExpected) ||
      normExpected.contains(normActual);
}

/// Bias geocoding toward a region around [center] (Geocoding Plus `extent`).
NeshanGeocodingExtent geocodeExtentAround(
  NeshanLatLng center, {
  double radiusKm = 80,
}) {
  final latRad = center.latitude * math.pi / 180;
  final dLat = radiusKm / 111.0;
  final dLng = radiusKm / (111.0 * math.cos(latRad).abs().clamp(0.2, 1.0));

  return NeshanGeocodingExtent(
    southWest: NeshanLatLng(
      latitude: center.latitude - dLat,
      longitude: center.longitude - dLng,
    ),
    northEast: NeshanLatLng(
      latitude: center.latitude + dLat,
      longitude: center.longitude + dLng,
    ),
  );
}

bool isPlausibleIranCoordinate(NeshanLatLng location) {
  return location.latitude >= 24 &&
      location.latitude <= 40 &&
      location.longitude >= 44 &&
      location.longitude <= 64;
}

/// True when [result] title/address text overlaps the user-entered [address].
bool resultMatchesAddressTerms(
  NeshanGeocodingResult result,
  String address,
) {
  if (isSpuriousDefaultSearchPoi(result, address)) return false;

  final hints = extractGeocodeHints(address);
  final query = extractGeocodeQuery(address, hints: hints);
  final terms = _significantTerms(query.isNotEmpty ? query : address);

  if (_resultOverlapsAddressTerms(result, terms)) return true;

  final unmatched = (result.unMatchedTerm ?? '').trim();
  final hasTitle = result.title != null && result.title!.trim().isNotEmpty;

  // Geocoding Plus full match with no metadata overlap.
  if (unmatched.isEmpty && !hasTitle) {
    if (terms.isEmpty) return true;
    if (_resultOverlapsAddressTerms(result, terms)) return true;
    if (geocodedCityMatchesAddress(result: result, address: address)) {
      if (isCityCentreGeocodingSnap(result, address)) return false;
      // POI names (metro stations, squares, …) must overlap result metadata.
      if (isPoiAddress(address)) return false;
      return true;
    }
    return false;
  }

  if (terms.isEmpty) {
    if (hasTitle) return false;
    return unmatched.isEmpty;
  }

  return false;
}

bool _resultOverlapsAddressTerms(
  NeshanGeocodingResult result,
  List<String> terms,
) {
  if (terms.isEmpty) return false;

  final searchable = _normalizeAddress(
    [
      result.title,
      result.formattedAddress,
      result.neighbourhood,
    ].whereType<String>().join(' '),
  );

  for (final term in terms) {
    if (searchable.contains(term)) return true;
    if (searchable.split(' ').any(
      (word) => word.length >= 3 && (word.contains(term) || term.contains(word)),
    )) {
      return true;
    }
  }
  return false;
}

bool isNearCityCentroid(NeshanGeocodingResult result, String address) {
  final hints = extractGeocodeHints(address);
  final cityKey = hints.city ?? result.city;
  if (cityKey == null) return false;
  final centroid = iranCityCentroids[cityKey];
  if (centroid == null) return false;
  return distanceMeters(
        LatLng(result.location.latitude, result.location.longitude),
        LatLng(centroid.latitude, centroid.longitude),
      ) <=
      2800;
}

/// True when [result] is a confident match for [address].
bool isConfidentGeocodingMatch(
  NeshanGeocodingResult result,
  String address,
) =>
    geocodingMatchScore(result, address) >= kMinGeocodingMatchScore;

/// Only reject coordinates that must never be used (known false POI snaps).
bool isHardRejectGeocodingResult(
  NeshanGeocodingResult result,
  String address,
) {
  if (!isPlausibleIranCoordinate(result.location)) return true;
  if (!geocodedCityMatchesAddress(result: result, address: address)) return true;
  return isSpuriousDefaultSearchPoi(result, address) ||
      isKnownNeshanFalsePositiveLocation(result, address);
}

/// Soft quality check — used in tests; navigation accepts nearest valid match.
bool isClearlyWrongGeocodingResult(
  NeshanGeocodingResult result,
  String address,
) {
  if (!isPlausibleIranCoordinate(result.location)) return true;
  if (!geocodedCityMatchesAddress(result: result, address: address)) return true;

  if (isSpuriousDefaultSearchPoi(result, address)) return true;

  if (isCityCentreGeocodingSnap(result, address)) return true;

  // Geocoding Plus full match — only trust when terms overlap or address is
  // city-level (no street/POI). Otherwise we accept city-centre false positives.
  if (isGeocodingPlusFullMatch(result) &&
      geocodedCityMatchesAddress(result: result, address: address)) {
    if (!hasSpecificLocationTerms(address)) return false;
    if (resultMatchesAddressTerms(result, address)) return false;
    if (isCityCentreGeocodingSnap(result, address)) return true;
    // Same-city street full match — trust Geocoding Plus neighbourhood snap.
    if (!isPoiAddress(address)) return false;
    if (isKnownNeshanFalsePositiveLocation(result, address)) return true;
    if (isNearCityCentroid(result, address)) return true;
    // POI away from the city-centre cluster — trust API rank (Search unavailable).
    return false;
  }

  final unmatched = (result.unMatchedTerm ?? '').trim();
  final relates = resultMatchesAddressTerms(result, address);

  // Street: Plus matched the main address; leftover is usually پلاک/واحد.
  if (!isPoiAddress(address) &&
      unmatched.isNotEmpty &&
      unmatched.length <= 12 &&
      geocodedCityMatchesAddress(result: result, address: address)) {
    return false;
  }

  if (!relates) return true;

  if (unmatched.isEmpty) return false;

  if (isPoiAddress(address) &&
      unmatched.length > 2 &&
      geocodingMatchScore(result, address) < 3) {
    return true;
  }

  return false;
}
