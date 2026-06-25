import 'dart:math' as math;

import 'package:uzita/services/neshan_models.dart';

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

String _normalizeAddress(String address) {
  return address
      .replaceAll('\u200c', ' ')
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('  ', ' ')
      .trim();
}

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
}) {
  final city = hints.city;
  final province = hints.province;

  if (city != null) {
    final centroid = iranCityCentroids[city];
    if (centroid != null) {
      return (
        city: city,
        province: province,
        searchCenter: centroid,
        searchExtent: geocodeExtentAround(centroid, radiusKm: 55),
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

  return (city: null, province: null, searchCenter: null, searchExtent: null);
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

  final normalized = _normalizeAddress(query);
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

  if (terms.isNotEmpty && score < 8) score -= 5;
  return score;
}

List<String> _significantTerms(String text) {
  final normalized = _normalizeAddress(text);
  final raw = normalized.split(RegExp(r'[,،\-–\s]+'));
  final terms = <String>[];
  for (final part in raw) {
    final term = part.trim();
    if (term.length < 3) continue;
    if (_isGenericAddressWord(term)) continue;
    terms.add(term);
  }
  return terms;
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
  };
  return generic.contains(word);
}

/// Pick the Geocoding Plus candidate that best matches [address].
NeshanGeocodingCandidate pickBestGeocodingCandidate(
  List<NeshanGeocodingCandidate> candidates,
  String address,
) {
  if (candidates.isEmpty) {
    throw ArgumentError('candidates must not be empty');
  }
  if (candidates.length == 1) return candidates.first;

  final hints = extractGeocodeHints(address);
  final expectedCity = hints.city != null ? _normalizeCityName(hints.city!) : null;

  NeshanGeocodingCandidate? best;
  var bestScore = -1000;

  for (final candidate in candidates) {
    final score = _candidateMatchScore(
      candidate,
      address: address,
      expectedCity: expectedCity,
    );
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  return best ?? candidates.first;
}

/// Pick the candidate that best matches the expected city and POI terms.
NeshanGeocodingResult refineGeocodingResult(
  NeshanGeocodingResult result, {
  required String address,
}) {
  if (result.candidates.isEmpty) return result;

  final best = pickBestGeocodingCandidate(result.candidates, address);
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

  final unmatched = (candidate.unMatchedTerm ?? '').trim().length;
  if (isPoiAddress(address)) {
    // Do not prefer empty unMatchedTerm when a landmark POI was provided — that
    // often means the API snapped to a generic city-centre point.
    score -= unmatched == 0 ? 2 : 0;
  } else {
    score -= unmatched;
  }

  return score;
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
