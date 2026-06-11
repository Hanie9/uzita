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

  Future<bool> requestPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<DriverLocationStatus> start({
    required void Function(DriverLocationSnapshot update) onUpdate,
    void Function(Object error)? onError,
  }) async {
    final granted = await requestPermission();
    if (!granted) {
      return DriverLocationStatus.permissionDenied;
    }

    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      return DriverLocationStatus.serviceDisabled;
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
