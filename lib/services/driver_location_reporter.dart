import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';

/// Periodically POSTs the driver's live location to the backend so service
/// managers can track where the driver is for a given cargo assignment.
///
/// Endpoint: `POST {apiBaseUrl}/transport/location/{assignmentId}`
/// Body: `{"latitude": .., "longitude": ..}`
class DriverLocationReporter {
  DriverLocationReporter({
    this.interval = const Duration(seconds: 10),
  });

  final Duration interval;

  Timer? _timer;
  int? _assignmentId;
  double? _latitude;
  double? _longitude;
  bool _sending = false;

  bool get isRunning => _timer != null;

  /// Updates the latest known position to be reported on the next tick.
  void updatePosition(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
  }

  /// Starts reporting every [interval] for the given cargo [assignmentId].
  void start(int assignmentId) {
    _assignmentId = assignmentId;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _send());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _send() async {
    if (_sending) return;
    final id = _assignmentId;
    final lat = _latitude;
    final lng = _longitude;
    if (id == null || lat == null || lng == null) return;

    _sending = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) return;

      await http
          .post(
            Uri.parse('$apiBaseUrl/transport/location/$id'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'latitude': lat, 'longitude': lng}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DriverLocationReporter failed: $e');
      }
    } finally {
      _sending = false;
    }
  }
}
