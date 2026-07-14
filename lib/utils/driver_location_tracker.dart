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

  /// Preferred accuracy for the first lock (meters).
  static const double _goodAccuracyMeters = 50;

  /// Acceptable accuracy while tracking or as a quick initial fix.
  static const double _coarseAccuracyMeters = 200;

  /// Last-resort accuracy after the grace period on weak GPS.
  static const double _fallbackAccuracyMeters = 500;

  /// How long to wait before accepting a coarse first fix.
  static const Duration _coarseGracePeriod = Duration(milliseconds: 1500);

  /// How long to wait before accepting any plausible fix.
  static const Duration _gracePeriod = Duration(seconds: 3);

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

    if (accuracy > 0 && accuracy <= _goodAccuracyMeters) return true;

    if (_hasAcceptedFix) {
      return accuracy > 0 && accuracy <= _coarseAccuracyMeters;
    }

    final startedAt = _trackingStartedAt;
    if (startedAt == null) return false;
    final elapsed = DateTime.now().difference(startedAt);

    if (elapsed >= _coarseGracePeriod &&
        accuracy > 0 &&
        accuracy <= _coarseAccuracyMeters) {
      return true;
    }

    return elapsed >= _gracePeriod &&
        accuracy > 0 &&
        accuracy <= _fallbackAccuracyMeters;
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

    unawaited(_emitBootstrapFix(onUpdate));

    _lastStatus = DriverLocationStatus.tracking;
    return DriverLocationStatus.tracking;
  }

  /// Fast first position: last-known fix, then a short medium-accuracy request.
  Future<DriverLocationSnapshot?> getBootstrapSnapshot() async {
    final lastKnown = await _readLastKnownPosition();
    if (lastKnown != null) return lastKnown;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
      if (!_isPlausibleCoordinate(position)) return null;
      return _toSnapshot(position);
    } catch (_) {
      return null;
    }
  }

  Future<DriverLocationSnapshot?> getCurrentSnapshot() => getBootstrapSnapshot();

  Future<void> _emitBootstrapFix(
    void Function(DriverLocationSnapshot update) onUpdate,
  ) async {
    final snapshot = await getBootstrapSnapshot();
    if (snapshot == null || _hasAcceptedFix) return;
    _hasAcceptedFix = true;
    onUpdate(snapshot);
  }

  Future<DriverLocationSnapshot?> _readLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null || !_isPlausibleCoordinate(position)) return null;
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
