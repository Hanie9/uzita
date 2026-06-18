import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/services/neshan_android_channel.dart';
import 'package:uzita/services/neshan_backend_client.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/neshan_config.dart';

/// Geocoding + routing with live traffic — Neshan only.
///
/// Geocoding: backend Geocoding Plus → REST Geocoding Plus (no Android search).
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
    final fromBackend = await _tryBackend(
      (token) => _backend.geocodeAddress(
        address,
        authToken: token,
        city: city,
        province: province,
        searchCenter: searchCenter,
        searchExtent: searchExtent,
      ),
    );
    if (fromBackend != null) return fromBackend;

    if (hasDirectNeshanKey) {
      return _neshan.geocodeAddress(
        address,
        city: city,
        province: province,
        searchCenter: searchCenter,
        searchExtent: searchExtent,
      );
    }

    throw const NeshanApiException(
      'Neshan API key is not configured',
      neshanStatus: 'KeyNotFound',
    );
  }

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
    final live = await _fetchLiveRoute(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      alternative: alternative,
      waypoints: waypoints,
      avoidTrafficZone: avoidTrafficZone,
      avoidOddEvenZone: avoidOddEvenZone,
      bearing: bearing,
    );

    final baseline = await _tryFetchNoTrafficRoute(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
      alternative: alternative,
      waypoints: waypoints,
      avoidTrafficZone: avoidTrafficZone,
      avoidOddEvenZone: avoidOddEvenZone,
      bearing: bearing,
    );

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

  Future<NeshanRoute?> _tryFetchNoTrafficRoute({
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
        () => _neshan.getNoTrafficRoute(
          origin: origin,
          destination: destination,
          vehicleType: vehicleType,
          alternative: alternative,
          waypoints: waypoints,
          avoidTrafficZone: avoidTrafficZone,
          avoidOddEvenZone: avoidOddEvenZone,
          bearing: bearing,
        ),
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
      // Typical-pattern routing from Neshan — fallback baseline when the
      // no-traffic endpoint is not enabled on the API key.
      if (hasDirectNeshanKey)
        () => _neshan.getTypicalRoute(
          origin: origin,
          destination: destination,
          vehicleType: vehicleType,
          alternative: alternative,
          waypoints: waypoints,
          avoidTrafficZone: avoidTrafficZone,
          avoidOddEvenZone: avoidOddEvenZone,
          bearing: bearing,
        ),
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
    if (kIsWeb || !hasNeshanApiKey) return null;

    final token = await _loadAuthToken();
    if (token == null || token.isEmpty) return null;

    try {
      return await call(token);
    } on NeshanApiException catch (e) {
      switch (e.neshanStatus) {
        case 'BackendProxyNotFound':
        case 'BackendKeyMissing':
          return null;
        default:
          rethrow;
      }
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
