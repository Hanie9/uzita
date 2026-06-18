import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uzita/api_config.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/neshan_error_codes.dart';

/// Calls Neshan via device-control backend (service key stays on server).
class NeshanBackendClient {
  const NeshanBackendClient();

  Future<NeshanGeocodingResult> geocodeAddress(
    String address, {
    required String authToken,
    String? city,
    String? province,
    NeshanLatLng? searchCenter,
    NeshanGeocodingExtent? searchExtent,
  }) async {
    final trimmed = address.trim();
    final requestBody = <String, dynamic>{
      'address': trimmed,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (province != null && province.trim().isNotEmpty)
        'province': province.trim(),
      if (searchCenter != null) 'location': searchCenter.toJson(),
      if (searchExtent != null) 'extent': searchExtent.toJson(),
    };

    final uri = Uri.parse('$apiBaseUrl/transport/neshan/geocode').replace(
      queryParameters: {'json': jsonEncode(requestBody)},
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    );

    final body = utf8.decode(response.bodyBytes);
    _ensureOk(response.statusCode, body);

    return const NeshanService().parseGeocodingBody(body, trimmed);
  }

  Future<NeshanRoute> getRoute({
    required String authToken,
    required NeshanLatLng origin,
    required NeshanLatLng destination,
    String vehicleType = 'car',
    bool alternative = false,
    List<NeshanLatLng>? waypoints,
    bool avoidTrafficZone = false,
    bool avoidOddEvenZone = false,
    double? bearing,
    bool liveTraffic = true,
    String trafficMode = 'live',
  }) async {
    final params = <String, String>{
      'type': vehicleType,
      'origin': origin.coordinateParam,
      'destination': destination.coordinateParam,
      'alternative': alternative.toString(),
      'avoidTrafficZone': avoidTrafficZone.toString(),
      'avoidOddEvenZone': avoidOddEvenZone.toString(),
      if (!liveTraffic) 'traffic': trafficMode,
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      params['waypoints'] = waypoints.map((p) => p.coordinateParam).join('|');
    }
    if (bearing != null) {
      params['bearing'] = bearing.clamp(0, 360).round().toString();
    }

    final uri = Uri.parse('$apiBaseUrl/transport/neshan/route').replace(
      queryParameters: params,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    );

    final body = utf8.decode(response.bodyBytes);
    _ensureOk(response.statusCode, body);

    return const NeshanService().parseRouteBody(body);
  }

  void _ensureOk(int statusCode, String body) {
    if (statusCode == 404) {
      throw const NeshanApiException(
        'Neshan backend proxy is not deployed',
        statusCode: 404,
        neshanStatus: 'BackendProxyNotFound',
      );
    }
    if (statusCode == 503) {
      throw const NeshanApiException(
        'NESHAN_API_KEY is not configured on the server',
        statusCode: 503,
        neshanStatus: 'BackendKeyMissing',
      );
    }
    if (statusCode != 200) {
      throw NeshanApiException(
        'Backend proxy failed ($statusCode)',
        statusCode: statusCode,
        neshanStatus: NeshanErrorCodes.backendProxyFailed,
      );
    }
  }
}
