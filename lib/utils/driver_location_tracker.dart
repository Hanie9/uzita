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

  DriverLocationStatus get lastStatus => _lastStatus;

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

    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) => onUpdate(_toSnapshot(position)),
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
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() => stop();
}
