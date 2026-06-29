import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/services/neshan_android_channel.dart';
import 'package:uzita/services/neshan_backend_client.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/address_geocode_hints.dart';
import 'package:uzita/utils/neshan_config.dart';
import 'package:uzita/utils/neshan_error_codes.dart';

/// Geocoding + routing with live traffic — Neshan only.
///
/// Geocoding (Geocoding Plus via backend/direct REST; Search only if enabled).
/// Routing: backend proxy → Android SDK → v4/direction REST.
class DriverRoutingService {
  const DriverRoutingService();

  static const _android = NeshanAndroidChannel();
  static const _neshan = NeshanService();
  static const _backend = NeshanBackendClient();

  bool get canNavigate => hasNeshanApiKey || hasDirectNeshanKey;

  Future<NeshanGeocodingResult> geocodeAddress(
    String address, {
    String? city,
    String? province,
    NeshanLatLng? searchCenter,
    NeshanGeocodingExtent? searchExtent,
  }) async {
    final hints = extractGeocodeHints(address);
    final terms = buildGeocodeSearchTerms(address, hints: hints);
    final poi = isPoiAddress(address);

    var center = searchCenter ??
        _searchCenterForAddress(
          hints: hints,
          searchCenter: null,
          plus: null,
        );

    NeshanGeocodingResult? best;
    NeshanGeocodingResult? fallback;
    var bestScore = -1000;
    var fallbackScore = -1000;

    void consider(NeshanGeocodingResult? candidate, {int bonus = 0}) {
      if (candidate == null) return;

      final ranked = candidate.candidates.isNotEmpty
          ? candidate.candidates
          : [
              NeshanGeocodingCandidate(
                location: candidate.location,
                province: candidate.province,
                city: candidate.city,
                neighbourhood: candidate.neighbourhood,
                unMatchedTerm: candidate.unMatchedTerm,
                title: candidate.title,
                formattedAddress: candidate.formattedAddress,
              ),
            ];

      for (var i = 0; i < ranked.length; i++) {
        final item = ranked[i];
        final refined = NeshanGeocodingResult(
          location: item.location,
          province: item.province,
          city: item.city,
          neighbourhood: item.neighbourhood,
          unMatchedTerm: item.unMatchedTerm,
          title: item.title,
          formattedAddress: item.formattedAddress,
          candidates: candidate.candidates,
        );
        if (isHardRejectGeocodingResult(refined, address)) continue;

        var score = geocodingMatchScore(refined, address) + bonus;
        // https://platform.neshan.org/docs/api/search-category/geocoding/
        score += (ranked.length - i) * 2;
        if (isGeocodingPlusFullMatch(refined) &&
            resultMatchesAddressTerms(refined, address)) {
          score += 10;
        } else if (isGeocodingPlusFullMatch(refined)) {
          score += 1;
        }
        if (resultMatchesAddressTerms(refined, address)) score += 6;
        if (isGeocodeWithinBias(
          refined,
          address: address,
          bias: searchCenter ?? center,
        )) {
          score += 4;
        }
        if (isCityCentreGeocodingSnap(refined, address)) {
          score -= 55;
        } else if (isClearlyWrongGeocodingResult(refined, address)) {
          score -= 25;
        }
        if (isKnownNeshanFalsePositiveLocation(refined, address)) {
          score -= 80;
        }

        if (score > bestScore) {
          bestScore = score;
          best = refined;
        }

        // Reserve a same-city API match when strict scoring rejects everything.
        if (!isSpuriousDefaultSearchPoi(refined, address) &&
            !isKnownNeshanFalsePositiveLocation(refined, address) &&
            !isClearlyWrongGeocodingResult(refined, address) &&
            geocodedCityMatchesAddress(result: refined, address: address) &&
            (!isCityCentreGeocodingSnap(refined, address) ||
                !hasSpecificLocationTerms(address))) {
          var fb = geocodingMatchScore(refined, address) + bonus + (ranked.length - i);
          final unmatched = (refined.unMatchedTerm ?? '').trim();
          if (unmatched.isNotEmpty &&
              !isPoiAddress(address) &&
              unmatched.length <= 24) {
            fb += 10;
          }
          if (isGeocodingPlusFullMatch(refined)) fb += 5;
          if (fb > fallbackScore) {
            fallbackScore = fb;
            fallback = refined;
          }
        }
      }
    }

    Future<void> runPlaceSearch() async {
      for (final term in terms) {
        consider(
          await _tryPlaceSearch(
            term,
            address: address,
            center: center,
          ),
          bonus: poi ? 8 : 4,
        );
      }
    }

    Future<void> runGeocodePlus() async {
      final plusTerms = <String>[];
      void addPlusTerm(String? value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty || trimmed == '---') return;
        if (!plusTerms.contains(trimmed)) plusTerms.add(trimmed);
      }

      // Neshan Geocoding Plus: send full address text; city/province in filters.
      addPlusTerm(geocodeApiAddressText(address));
      for (final term in terms) {
        addPlusTerm(geocodeApiAddressText(term));
      }

      for (final term in plusTerms) {
        final plus = await _tryGeocodePlus(
          term,
          address: address,
          city: city,
          province: province,
          searchCenter: poi ? null : searchCenter,
          searchExtent: poi ? null : searchExtent,
        );
        consider(plus, bonus: poi ? 0 : 6);
        if (plus != null) {
          center = _searchCenterForAddress(
            hints: hints,
            searchCenter: searchCenter,
            plus: best ?? plus,
          );
        }
      }
    }

    // Geocoding Plus first; place search for POIs (metro stations, squares, …)
    // even when REST Search is disabled — Geocoding Plus alone often snaps wrong.
    await runGeocodePlus();
    if (neshanSearchEnabled || poi) {
      await runPlaceSearch();
    }

    if (best == null) {
      best = fallback;
    } else if (bestScore < kMinGeocodingMatchScore && fallback != null) {
      if (fallbackScore > bestScore) best = fallback;
    }

    if (best != null && isClearlyWrongGeocodingResult(best!, address)) {
      if (fallback != null &&
          !isClearlyWrongGeocodingResult(fallback!, address)) {
        best = fallback;
      } else {
        best = null;
      }
    }

    if (best == null) {
      throw const NeshanApiException(
        'No location found for address',
        neshanStatus: NeshanErrorCodes.geocodingNotFound,
      );
    }

    return best!;
  }

  /// Resolves a cargo [mabda]/[maghsad] string with city/sibling bias only.
  Future<NeshanGeocodingResult> resolveCargoAddress(
    String address, {
    NeshanGeocodingResult? siblingResult,
    NeshanLatLng? driverLocation,
  }) async {
    final hints = extractGeocodeHints(address);
    final params = buildCargoGeocodeParams(
      address: address,
      hints: hints,
      siblingResult: siblingResult,
    );
    return geocodeAddress(
      address,
      city: params.city,
      province: params.province,
      searchCenter: params.searchCenter,
      searchExtent: params.searchExtent,
    );
  }

  Future<NeshanGeocodingResult?> _tryPlaceSearch(
    String term, {
    required String address,
    required NeshanLatLng center,
  }) async {
    if (_android.isAvailable) {
      try {
        return await _android.searchAddress(
          term,
          searchCenter: center,
          scoringAddress: address,
        );
      } catch (_) {}
    }

    final fromBackend = await _tryBackend(
      (token) => _backend.searchAddress(
        term,
        authToken: token,
        center: center,
        scoringAddress: address,
      ),
    );
    if (fromBackend != null) return fromBackend;

    if (!hasDirectNeshanKey) return null;

    try {
      return await _neshan.searchAddress(
        term,
        center: center,
        scoringAddress: address,
      );
    } catch (_) {
      return null;
    }
  }

  Future<NeshanGeocodingResult?> _tryGeocodePlus(
    String apiText, {
    required String address,
    String? city,
    String? province,
    NeshanLatLng? searchCenter,
    NeshanGeocodingExtent? searchExtent,
  }) async {
    final fromBackend = await _tryBackend(
      (token) => _backend.geocodeAddress(
        apiText,
        authToken: token,
        city: city,
        province: province,
        searchCenter: searchCenter,
        searchExtent: searchExtent,
      ),
    );
    if (fromBackend != null) return fromBackend;

    if (!hasDirectNeshanKey) return null;

    try {
      return await _neshan.geocodeAddress(
        apiText,
        city: city,
        province: province,
        searchCenter: searchCenter,
        searchExtent: searchExtent,
      );
    } on NeshanApiException {
      return null;
    }
  }

  NeshanLatLng _searchCenterForAddress({
    required AddressGeocodeHints hints,
    required NeshanLatLng? searchCenter,
    required NeshanGeocodingResult? plus,
  }) {
    if (searchCenter != null) return searchCenter;
    final city = hints.city;
    if (city != null) {
      final centroid = iranCityCentroids[city];
      if (centroid != null) return centroid;
    }
    if (plus != null) return plus.location;
    return const NeshanLatLng(latitude: 35.6892, longitude: 51.3890);
  }

  /// Live route with a typical/no-traffic baseline fetched in parallel (for map colours).
  Future<NeshanRoute> getRouteWithTraffic({
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
  }) async {
    final liveFuture = _fetchLiveRoute(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      alternative: alternative,
      waypoints: waypoints,
      avoidTrafficZone: avoidTrafficZone,
      avoidOddEvenZone: avoidOddEvenZone,
      bearing: bearing,
    );
    final baselineFuture = _tryFetchTrafficBaselineRoute(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      alternative: alternative,
      waypoints: waypoints,
      avoidTrafficZone: avoidTrafficZone,
      avoidOddEvenZone: avoidOddEvenZone,
      bearing: bearing,
    );

    final live = await liveFuture;
    NeshanRoute? baseline;
    try {
      baseline = await baselineFuture.timeout(const Duration(seconds: 8));
    } catch (_) {
      baseline = null;
    }
    return live.withBaseline(baseline);
  }

  /// Live traffic route. Does not wait for a no-traffic baseline — call
  /// [getRouteWithTraffic] or [attachTrafficBaseline] for coloured segments.
  Future<NeshanRoute> getRoute({
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
  }) async {
    return _fetchLiveRoute(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      alternative: alternative,
      waypoints: waypoints,
      avoidTrafficZone: avoidTrafficZone,
      avoidOddEvenZone: avoidOddEvenZone,
      bearing: bearing,
    );
  }

  /// Adds a typical/no-traffic baseline for per-segment traffic colouring.
  Future<NeshanRoute> attachTrafficBaseline(
    NeshanRoute live, {
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
  }) async {
    if (live.baselineRoute != null) return live;

    NeshanRoute? baseline;
    try {
      baseline = await _tryFetchTrafficBaselineRoute(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      baseline = null;
    }
    return live.withBaseline(baseline);
  }

  Future<NeshanRoute> _fetchLiveRoute({
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
  }) async {
    final fromBackend = await _tryBackend(
      (token) => _backend.getRoute(
        authToken: token,
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
        liveTraffic: true,
      ),
    );
    if (fromBackend != null) return fromBackend;

    if (_android.isAvailable) {
      try {
        return await _android.getRoute(
          origin: origin,
          destination: destination,
          vehicleType: vehicleType,
          alternative: alternative,
          waypoints: waypoints,
          avoidTrafficZone: avoidTrafficZone,
          avoidOddEvenZone: avoidOddEvenZone,
        );
      } on NeshanApiException {
        // Fall through to direct REST.
      }
    }

    if (hasDirectNeshanKey) {
      return _neshan.getRoute(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
      );
    }

    throw const NeshanApiException(
      'Neshan API key is not configured',
      neshanStatus: 'KeyNotFound',
    );
  }

  /// No-traffic baseline first — best contrast for congestion on the route line.
  Future<NeshanRoute?> _tryFetchTrafficBaselineRoute({
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
  }) async {
    final attempts = <Future<NeshanRoute?> Function()>[
      () => _tryBackendNoTraffic(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
        trafficMode: 'none',
      ),
      if (hasDirectNeshanKey)
        () async {
          try {
            return await _neshan.getNoTrafficRoute(
              origin: origin,
              destination: destination,
              vehicleType: vehicleType,
              alternative: alternative,
              waypoints: waypoints,
              avoidTrafficZone: avoidTrafficZone,
              avoidOddEvenZone: avoidOddEvenZone,
              bearing: bearing,
            );
          } catch (_) {
            return null;
          }
        },
      () => _tryBackendNoTraffic(
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
        trafficMode: 'typical',
      ),
      if (hasDirectNeshanKey)
        () async {
          try {
            return await _neshan.getTypicalRoute(
              origin: origin,
              destination: destination,
              vehicleType: vehicleType,
              alternative: alternative,
              waypoints: waypoints,
              avoidTrafficZone: avoidTrafficZone,
              avoidOddEvenZone: avoidOddEvenZone,
              bearing: bearing,
            );
          } catch (_) {
            return null;
          }
        },
    ];

    for (final attempt in attempts) {
      try {
        final route = await attempt();
        if (route != null) return route;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<NeshanRoute?> _tryBackendNoTraffic({
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
    String trafficMode = 'none',
  }) async {
    return _tryBackend(
      (token) => _backend.getRoute(
        authToken: token,
        origin: origin,
        destination: destination,
        vehicleType: vehicleType,
        alternative: alternative,
        waypoints: waypoints,
        avoidTrafficZone: avoidTrafficZone,
        avoidOddEvenZone: avoidOddEvenZone,
        bearing: bearing,
        liveTraffic: false,
        trafficMode: trafficMode,
      ),
    );
  }

  Future<T?> _tryBackend<T>(Future<T> Function(String token) call) async {
    if (kIsWeb) return null;

    final token = await _loadAuthToken();
    if (token == null || token.isEmpty) return null;

    try {
      return await call(token);
    } on NeshanApiException catch (e) {
      if (_shouldFallbackFromBackend(e)) return null;
      rethrow;
    }
  }

  bool _shouldFallbackFromBackend(NeshanApiException error) {
    switch (error.neshanStatus) {
      case 'BackendProxyNotFound':
      case 'BackendKeyMissing':
      case NeshanErrorCodes.backendProxyFailed:
      case 'ApiWhiteListError':
      case 'ApiKeyTypeError':
      case 'ApiServiceListError':
      case 'KeyNotFound':
      case 'LimitExceeded':
      case 'RateExceeded':
        return true;
      default:
        return false;
    }
  }

  Future<String?> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (_) {
      return null;
    }
  }
}
