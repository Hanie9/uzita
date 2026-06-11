import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/neshan_config.dart';
import 'package:uzita/utils/validated_network_tile_provider.dart';

/// Builds URL for Neshan static arc map (origin → destination).
Uri buildNeshanStaticArcUri({
  required NeshanLatLng from,
  required NeshanLatLng to,
  required int width,
  required int height,
  bool dark = false,
}) {
  return Uri.parse(neshanStaticArcUrl).replace(
    queryParameters: {
      'key': neshanApiKey,
      'type': dark ? 'standard-night' : 'dreamy',
      'from': '${from.latitude},${from.longitude}',
      'to': '${to.latitude},${to.longitude}',
      'width': '$width',
      'height': '$height',
      'dashed': 'false',
      'color': '%231E3A8A',
    },
  );
}

Future<Uint8List> fetchNeshanStaticArcImage({
  required NeshanLatLng from,
  required NeshanLatLng to,
  required int width,
  required int height,
  bool dark = false,
  String? authToken,
}) async {
  if (!kIsWeb && (authToken?.trim().isNotEmpty ?? false)) {
    return _fetchStaticArcViaBackend(
      from: from,
      to: to,
      width: width,
      height: height,
      dark: dark,
      authToken: authToken!.trim(),
    );
  }

  if (!hasNeshanApiKey) {
    throw Exception('Neshan API key is not configured');
  }

  final uri = buildNeshanStaticArcUri(
    from: from,
    to: to,
    width: width,
    height: height,
    dark: dark,
  );

  final response = await http.get(
    uri,
    headers: {'Api-Key': neshanApiKey},
  );

  if (response.statusCode != 200) {
    throw Exception('Static map failed (${response.statusCode})');
  }

  final bytes = response.bodyBytes;
  if (!isRasterImageBytes(bytes)) {
    throw Exception('Static map returned invalid image data');
  }
  return bytes;
}

Future<Uint8List> _fetchStaticArcViaBackend({
  required NeshanLatLng from,
  required NeshanLatLng to,
  required int width,
  required int height,
  required bool dark,
  required String authToken,
}) async {
  final uri = Uri.parse('$apiBaseUrl/transport/neshan/static-arc').replace(
    queryParameters: {
      'from': '${from.latitude},${from.longitude}',
      'to': '${to.latitude},${to.longitude}',
      'width': '$width',
      'height': '$height',
      'map_type': dark ? 'standard-night' : 'dreamy',
      'dashed': 'false',
      'color': '%231E3A8A',
    },
  );

  final response = await http.get(
    uri,
    headers: {
      'Authorization': 'Bearer $authToken',
      'Accept': 'image/*,application/json',
      'Cache-Control': 'no-cache',
    },
  );

  if (response.statusCode == 404) {
    throw Exception('Neshan backend proxy is not deployed');
  }
  if (response.statusCode == 503) {
    throw Exception('NESHAN_API_KEY is not configured on the server');
  }

  if (response.statusCode != 200) {
    throw Exception('Static map failed (${response.statusCode})');
  }

  final bytes = response.bodyBytes;
  if (!isRasterImageBytes(bytes)) {
    throw Exception('Static map returned invalid image data');
  }
  return bytes;
}

/// Approximate overlay position for driver on arc map image (0..1 along route).
Offset driverOverlayOnArcMap(Size size, List<LatLng> route, LatLng driver) {
  if (route.length < 2) {
    return Offset(size.width * 0.5, size.height * 0.5);
  }

  var closestIndex = 0;
  var closestDistance = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final d = _distance(route[i], driver);
    if (d < closestDistance) {
      closestDistance = d;
      closestIndex = i;
    }
  }

  final t = closestIndex / (route.length - 1);
  return Offset(
    size.width * (0.12 + 0.76 * t),
    size.height * (0.88 - 0.76 * t),
  );
}

double _distance(LatLng a, LatLng b) {
  final dLat = a.latitude - b.latitude;
  final dLng = a.longitude - b.longitude;
  return dLat * dLat + dLng * dLng;
}
