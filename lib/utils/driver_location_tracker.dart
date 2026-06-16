import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uzita/utils/driver_location_snapshot.dart';

export 'package:uzita/utils/driver_location_snapshot.dart';

enum DriverLocationStatus {
  tracking,
  permissionDenied,
  serviceDisabled,
  unavailable,
}

class DriverLocationTracker {
  StreamSubscription<Position>? _subscription;
  DriverLocationStatus _lastStatus = DriverLocationStatus.unavailable;

  /// First fix must be at least this accurate (meters) before we trust it.
  /// This filters out coarse network / last-known fixes that can be kilometers
  /// off and would otherwise produce a wrong, huge route.
  static const double _goodAccuracyMeters = 50;

  /// Upper bound for fixes accepted as a fallback / while already tracking.
  /// Anything coarser is treated as unreliable and dropped.
  static const double _coarseAccuracyMeters = 200;

  /// After this long without a good fix, accept the best one we've seen so the
  /// UI never gets stuck "searching" on a device with weak GPS.
  static const Duration _gracePeriod = Duration(seconds: 8);

  DateTime? _trackingStartedAt;
  bool _hasAcceptedFix = false;

  DriverLocationStatus get lastStatus => _lastStatus;

  /// Plausible bounds for Iran — drops garbage fixes like (0,0).
  static bool _isPlausibleCoordinate(Position position) {
    final lat = position.latitude;
    final lng = position.longitude;
    if (lat == 0 && lng == 0) return false;
    return lat >= 24 && lat <= 40.5 && lng >= 43 && lng <= 64;
  }

  bool _isAcceptableFix(Position position) {
    if (!_isPlausibleCoordinate(position)) return false;
    final accuracy = position.accuracy;

    // A good fix is always accepted.
    if (accuracy > 0 && accuracy <= _goodAccuracyMeters) return true;

    // Once we already locked onto a good fix, keep accepting reasonably accurate
    // fixes so live movement keeps updating (but still drop very coarse ones).
    if (_hasAcceptedFix) {
      return accuracy > 0 && accuracy <= _coarseAccuracyMeters;
    }

    // No good fix yet: after the grace period accept the best-effort fix so the
    // UI is not stuck "searching" on a device with weak GPS.
    final startedAt = _trackingStartedAt;
    final waitedLongEnough = startedAt != null &&
        DateTime.now().difference(startedAt) >= _gracePeriod;
    return waitedLongEnough && accuracy > 0 && accuracy <= _coarseAccuracyMeters;
  }

  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// Requests permission and opens system settings when needed.
  Future<bool> ensureAccess() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _lastStatus = DriverLocationStatus.permissionDenied;
      final handlerStatus = await Permission.locationWhenInUse.status;
      if (handlerStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    var enabled = await isLocationServiceEnabled();
    if (!enabled) {
      _lastStatus = DriverLocationStatus.serviceDisabled;
      await Geolocator.openLocationSettings();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      enabled = await isLocationServiceEnabled();
      if (!enabled) return false;
    }

    return true;
  }

  Future<DriverLocationStatus> start({
    required void Function(DriverLocationSnapshot update) onUpdate,
    void Function(Object error)? onError,
  }) async {
    final ready = await ensureAccess();
    if (!ready) {
      return _lastStatus;
    }

    _trackingStartedAt = DateTime.now();
    _hasAcceptedFix = false;

    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        if (!_isAcceptableFix(position)) return;
        _hasAcceptedFix = true;
        onUpdate(_toSnapshot(position));
      },
      onError: onError,
    );

    _lastStatus = DriverLocationStatus.tracking;
    return DriverLocationStatus.tracking;
  }

  Future<DriverLocationSnapshot?> getCurrentSnapshot() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      // Only trust the immediate fix if it is plausible and accurate; otherwise
      // wait for the stream to deliver a good fix.
      if (!_isPlausibleCoordinate(position)) return null;
      if (position.accuracy <= 0 || position.accuracy > _goodAccuracyMeters) {
        return null;
      }
      return _toSnapshot(position);
    } catch (_) {
      return null;
    }
  }

  DriverLocationSnapshot _toSnapshot(Position position) {
    final heading = position.heading;
    return DriverLocationSnapshot(
      position: LatLng(position.latitude, position.longitude),
      heading: heading >= 0 && heading <= 360 ? heading : null,
      speedMps: position.speed >= 0 ? position.speed : 0,
      accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _trackingStartedAt = null;
    _hasAcceptedFix = false;
  }

  void dispose() => stop();
}
