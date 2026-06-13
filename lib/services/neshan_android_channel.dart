import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/neshan_config.dart';

/// Neshan Android services-sdk (search geocoding + v4/direction routing).
class NeshanAndroidChannel {
  const NeshanAndroidChannel();

  static const _channel = MethodChannel('com.example.uzita/neshan_services');

  bool get isAvailable => !kIsWeb && Platform.isAndroid;

  Future<NeshanGeocodingResult> geocodeAddress(
    String address, {
    NeshanLatLng? searchCenter,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'geocodeAddress',
      {
        'address': address.trim(),
        if (searchCenter != null) ...{
          'centerLat': searchCenter.latitude,
          'centerLng': searchCenter.longitude,
        },
      },
    );

    if (response == null) {
      throw const NeshanApiException('Empty geocoding response from Neshan SDK');
    }

    final lat = _asDouble(response['latitude']);
    final lng = _asDouble(response['longitude']);
    if (lat == null || lng == null) {
      throw const NeshanApiException('Invalid geocoding coordinates from Neshan SDK');
    }

    return NeshanGeocodingResult(
      location: NeshanLatLng(latitude: lat, longitude: lng),
      city: response['title']?.toString(),
      neighbourhood: response['address']?.toString(),
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
  }) async {
    if (!hasNeshanApiKey) {
      throw const NeshanApiException(
        'Neshan API key is not configured',
        neshanStatus: 'KeyNotFound',
      );
    }

    final response = await _channel.invokeMapMethod<String, dynamic>(
      'getRoute',
      {
        'apiKey': neshanApiKey,
        'originLat': origin.latitude,
        'originLng': origin.longitude,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
        'vehicleType': vehicleType,
        'alternative': alternative,
        'avoidTrafficZone': avoidTrafficZone,
        'avoidOddEvenZone': avoidOddEvenZone,
        if (waypoints != null && waypoints.isNotEmpty)
          'waypoints': waypoints
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
      },
    );

    if (response == null) {
      throw const NeshanApiException('Empty routing response from Neshan SDK');
    }

    final legsRaw = response['legs'];
    if (legsRaw is! List || legsRaw.isEmpty) {
      throw const NeshanApiException('Route has no legs');
    }

    final legs = legsRaw
        .whereType<Map>()
        .map(
          (leg) => NeshanRouteLeg(
            summary: leg['summary']?.toString() ?? '',
            distanceText: leg['distanceText']?.toString() ?? '',
            distanceMeters: _asDouble(leg['distanceMeters']) ?? 0,
            durationText: leg['durationText']?.toString() ?? '',
            durationSeconds: _asDouble(leg['durationSeconds']) ?? 0,
            steps: _parseSteps(leg['steps']),
          ),
        )
        .toList(growable: false);

    if (legs.isEmpty) {
      throw const NeshanApiException('Route has no valid legs');
    }

    final polyline = response['overviewPolyline']?.toString();

    return NeshanRoute(
      legs: legs,
      overviewPolyline: polyline?.trim().isEmpty == true ? null : polyline,
    );
  }

  List<NeshanRouteStep> _parseSteps(dynamic stepsRaw) {
    if (stepsRaw is! List) return const [];

    return stepsRaw
        .whereType<Map>()
        .map(
          (step) => NeshanRouteStep(
            instruction: step['instruction']?.toString() ?? '',
            name: step['name']?.toString() ?? '',
            distanceText: step['distanceText']?.toString() ?? '',
            durationText: step['durationText']?.toString() ?? '',
            distanceMeters: _asDouble(step['distanceMeters']) ?? 0,
            durationSeconds: _asDouble(step['durationSeconds']) ?? 0,
            stepType: step['type']?.toString(),
            polyline: step['polyline']?.toString(),
            modifier: step['modifier']?.toString(),
            bearingAfter: _asDouble(step['bearingAfter']),
            startLocation: _parseLocation(step['startLat'], step['startLng']),
          ),
        )
        .where((step) => step.instruction.isNotEmpty || step.isArrival)
        .toList(growable: false);
  }

  NeshanLatLng? _parseLocation(dynamic lat, dynamic lng) {
    final latitude = _asDouble(lat);
    final longitude = _asDouble(lng);
    if (latitude == null || longitude == null) return null;
    return NeshanLatLng(latitude: latitude, longitude: longitude);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
