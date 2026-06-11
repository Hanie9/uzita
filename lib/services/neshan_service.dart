import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/neshan_api_codes.dart';
import 'package:uzita/utils/neshan_config.dart';

class NeshanApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? neshanStatus;

  const NeshanApiException(
    this.message, {
    this.statusCode,
    this.neshanStatus,
  });

  @override
  String toString() => message;
}

/// Direct Neshan REST API (Geocoding Plus + Routing v4 with live traffic).
class NeshanService {
  const NeshanService();

  Map<String, String> _headersFor(String apiKey) => {
    'Api-Key': apiKey,
    'Content-Type': 'application/json',
  };

  void _ensureDirectApiKey() {
    if (!hasDirectNeshanKey) {
      throw const NeshanApiException(
        'Neshan API key is not configured',
        neshanStatus: 'KeyNotFound',
      );
    }
  }

  /// Geocoding Plus — https://platform.neshan.org/docs/api/search-category/geocoding/
  Future<NeshanGeocodingResult> geocodeAddress(
    String address, {
    String? city,
    String? province,
    NeshanLatLng? searchCenter,
    NeshanGeocodingExtent? searchExtent,
  }) async {
    _ensureDirectApiKey();

    final trimmed = address.trim();
    if (trimmed.isEmpty || trimmed == '---') {
      throw const NeshanApiException('Address is empty');
    }

    final requestBody = <String, dynamic>{
      'address': trimmed,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (province != null && province.trim().isNotEmpty)
        'province': province.trim(),
      if (searchCenter != null) 'location': searchCenter.toJson(),
      if (searchExtent != null) 'extent': searchExtent.toJson(),
    };

    final uri = Uri.parse(neshanGeocodingBaseUrl).replace(
      queryParameters: {
        'json': jsonEncode(requestBody),
      },
    );

    final response = await http.get(
      uri,
      headers: _headersFor(neshanDirectApiKey),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode != 200) {
      throw _buildApiException(
        body,
        fallback: 'Geocoding request failed',
        httpStatus: response.statusCode,
      );
    }

    return parseGeocodingBody(body, trimmed);
  }

  /// Routing with live traffic — https://platform.neshan.org/docs/api/routing-category/routing/
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
    _ensureDirectApiKey();

    final params = <String, String>{
      'type': vehicleType,
      'origin': origin.coordinateParam,
      'destination': destination.coordinateParam,
      'alternative': alternative.toString(),
      'avoidTrafficZone': avoidTrafficZone.toString(),
      'avoidOddEvenZone': avoidOddEvenZone.toString(),
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      params['waypoints'] = waypoints.map((p) => p.coordinateParam).join('|');
    }
    if (bearing != null) {
      params['bearing'] = bearing.clamp(0, 360).round().toString();
    }

    final uri = Uri.parse(neshanDirectionBaseUrl).replace(
      queryParameters: params,
    );

    final response = await http.get(
      uri,
      headers: _headersFor(neshanDirectApiKey),
    );
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode != 200) {
      throw _buildApiException(
        body,
        fallback: 'Routing request failed',
        httpStatus: response.statusCode,
      );
    }

    return parseRouteBody(body);
  }

  NeshanGeocodingResult parseGeocodingBody(String body, String address) {
    final data = json.decode(body) as Map<String, dynamic>;
    final items = data['items'];
    if (items is! List || items.isEmpty) {
      throw NeshanApiException('No location found for address: $address');
    }

    final candidates = items
        .whereType<Map<String, dynamic>>()
        .map(_parseGeocodingItem)
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw NeshanApiException('No location found for address: $address');
    }

    final best = candidates.first;
    return NeshanGeocodingResult(
      location: best.location,
      province: best.province,
      city: best.city,
      neighbourhood: best.neighbourhood,
      unMatchedTerm: best.unMatchedTerm,
      candidates: candidates,
    );
  }

  NeshanGeocodingCandidate _parseGeocodingItem(Map<String, dynamic> item) {
    final location = item['location'];
    if (location is! Map<String, dynamic>) {
      throw const NeshanApiException('Invalid geocoding location');
    }

    final lat = _asDouble(location['latitude']);
    final lng = _asDouble(location['longitude']);
    if (lat == null || lng == null) {
      throw const NeshanApiException('Invalid geocoding coordinates');
    }

    return NeshanGeocodingCandidate(
      location: NeshanLatLng(latitude: lat, longitude: lng),
      province: item['province']?.toString(),
      city: item['city']?.toString(),
      neighbourhood: item['neighbourhood']?.toString(),
      unMatchedTerm: item['unMatchedTerm']?.toString(),
    );
  }

  NeshanRoute parseRouteBody(String body) {
    final data = json.decode(body) as Map<String, dynamic>;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const NeshanApiException(
        'No route found between origin and destination',
      );
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      throw const NeshanApiException('Invalid routing response');
    }

    final legsRaw = firstRoute['legs'];
    if (legsRaw is! List || legsRaw.isEmpty) {
      throw const NeshanApiException('Route has no legs');
    }

    final legs = legsRaw
        .whereType<Map<String, dynamic>>()
        .map(_parseLeg)
        .toList(growable: false);

    if (legs.isEmpty) {
      throw const NeshanApiException('Route has no valid legs');
    }

    final overview = firstRoute['overview_polyline'];
    final polyline = overview is Map<String, dynamic>
        ? overview['points']?.toString()
        : null;

    return NeshanRoute(
      legs: legs,
      overviewPolyline: polyline?.trim().isEmpty == true ? null : polyline,
    );
  }

  NeshanRouteLeg _parseLeg(Map<String, dynamic> leg) {
    final distance = leg['distance'];
    final duration = leg['duration'];
    final stepsRaw = leg['steps'];

    return NeshanRouteLeg(
      summary: leg['summary']?.toString() ?? '',
      distanceText: distance is Map ? distance['text']?.toString() ?? '' : '',
      distanceMeters: distance is Map ? _asDouble(distance['value']) ?? 0 : 0,
      durationText: duration is Map ? duration['text']?.toString() ?? '' : '',
      durationSeconds: duration is Map ? _asDouble(duration['value']) ?? 0 : 0,
      steps: stepsRaw is List
          ? stepsRaw
                .whereType<Map<String, dynamic>>()
                .map(_parseStep)
                .where(_isUsableStep)
                .toList(growable: false)
          : const [],
    );
  }

  bool _isUsableStep(NeshanRouteStep step) =>
      step.instruction.isNotEmpty || step.isArrival;

  NeshanRouteStep _parseStep(Map<String, dynamic> step) {
    final distance = step['distance'];
    final duration = step['duration'];
    final startLocation = step['start_location'];

    NeshanLatLng? location;
    if (startLocation is List && startLocation.length >= 2) {
      final lng = _asDouble(startLocation[0]);
      final lat = _asDouble(startLocation[1]);
      if (lat != null && lng != null) {
        location = NeshanLatLng(latitude: lat, longitude: lng);
      }
    }

    return NeshanRouteStep(
      instruction: step['instruction']?.toString() ?? '',
      name: step['name']?.toString() ?? '',
      distanceText: distance is Map ? distance['text']?.toString() ?? '' : '',
      durationText: duration is Map ? duration['text']?.toString() ?? '' : '',
      distanceMeters: distance is Map ? _asDouble(distance['value']) ?? 0 : 0,
      durationSeconds: duration is Map ? _asDouble(duration['value']) ?? 0 : 0,
      stepType: step['type']?.toString(),
      modifier: step['modifier']?.toString(),
      bearingAfter: _asDouble(step['bearing_after']),
      polyline: step['polyline']?.toString(),
      startLocation: location,
    );
  }

  NeshanApiException _buildApiException(
    String body, {
    required String fallback,
    required int httpStatus,
  }) {
    try {
      final data = json.decode(body);
      if (data is Map<String, dynamic>) {
        final neshanStatus = neshanStatusFromResponse(data);
        final message = data['message']?.toString() ?? '';
        final error = data['error']?.toString() ?? '';
        final text = message.isNotEmpty
            ? message
            : (error.isNotEmpty ? error : fallback);
        return NeshanApiException(
          text,
          statusCode: httpStatus,
          neshanStatus: neshanStatus,
        );
      }
    } catch (_) {}
    return NeshanApiException(fallback, statusCode: httpStatus);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
