import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_progress.dart';

/// Neshan native [MapView] on Android (license in res/raw/neshan.license).
class NeshanDriverMap extends StatefulWidget {
  final List<LatLng> routeCoordinates;
  final List<RouteMapSegment> routeSegments;
  final LatLng origin;
  final LatLng destination;
  final LatLng? driverPosition;
  final double? driverHeading;
  final bool followDriver;
  final bool isDark;
  final int? traveledFromIndex;

  const NeshanDriverMap({
    super.key,
    required this.routeCoordinates,
    this.routeSegments = const [],
    required this.origin,
    required this.destination,
    this.driverPosition,
    this.driverHeading,
    this.followDriver = false,
    this.isDark = false,
    this.traveledFromIndex,
  });

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  State<NeshanDriverMap> createState() => _NeshanDriverMapState();
}

class _NeshanDriverMapState extends State<NeshanDriverMap> {
  static const _channel = MethodChannel('com.example.uzita/neshan_map');
  int? _viewId;
  bool _fitted = false;
  bool _mapUpdatePending = false;

  List<LatLng> get _route =>
      widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  List<LatLng> get _fitPoints => [
    widget.origin,
    widget.destination,
    ..._route,
  ];

  bool get _shouldFollowDriver {
    final driver = widget.driverPosition;
    if (!widget.followDriver || driver == null) return false;
    return isNearRoutePolyline(
      point: driver,
      polyline: _route,
      origin: widget.origin,
      destination: widget.destination,
    );
  }

  List<RouteMapSegment> get _displaySegments {
    final traveledIndex = widget.traveledFromIndex ?? 0;

    if (widget.followDriver && traveledIndex > 0 && _route.length > traveledIndex) {
      final remaining = _route.sublist(traveledIndex);
      if (remaining.length >= 2) {
        return [RouteMapSegment(points: remaining, congested: false)];
      }
    }

    if (_route.length >= 2) {
      return [RouteMapSegment(points: _route, congested: false)];
    }
    return const [];
  }

  @override
  void didUpdateWidget(covariant NeshanDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_viewId == null) return;

    final routeChanged =
        widget.routeCoordinates.length != oldWidget.routeCoordinates.length ||
        widget.origin != oldWidget.origin ||
        widget.destination != oldWidget.destination;
    if (routeChanged) {
      _fitted = false;
    }

    _scheduleMapUpdate(refit: routeChanged || !_fitted);
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted || _viewId == null) return;
      await _scheduleMapUpdate(refit: true);
    });
  }

  Future<void> _scheduleMapUpdate({required bool refit}) async {
    if (_viewId == null || _mapUpdatePending) return;
    _mapUpdatePending = true;

    try {
      await _syncOverlays();
      if (!mounted || _viewId == null) return;

      if (_shouldFollowDriver) {
        await _moveCamera(
          widget.driverPosition!,
          zoom: 17,
          bearing: widget.driverHeading,
        );
      } else if (refit || !_fitted) {
        await _fitBounds();
      }
    } finally {
      _mapUpdatePending = false;
    }
  }

  Future<void> _fitBounds() async {
    final id = _viewId;
    if (id == null) return;
    final points = _fitPoints;
    if (points.isEmpty) return;

    try {
      await _channel.invokeMethod('fitBounds', {
        'viewId': id,
        'points': points.map(_point).toList(),
      });
      _fitted = true;
    } catch (_) {
      await _moveCamera(widget.origin, zoom: 13);
      _fitted = true;
    }
  }

  Future<void> _moveCamera(
    LatLng position, {
    required double zoom,
    double? bearing,
  }) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('moveCamera', {
        'viewId': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'zoom': zoom,
        if (bearing != null) 'bearing': bearing,
      });
    } catch (_) {
      // Map surface may not be ready yet.
    }
  }

  Future<void> _syncOverlays() async {
    final id = _viewId;
    if (id == null) return;

    final traveledIndex = widget.traveledFromIndex ?? 0;
    final traveled = traveledIndex > 0
        ? _route.sublist(0, traveledIndex.clamp(1, _route.length))
        : <LatLng>[];

    final segments = _displaySegments;

    try {
      await _channel.invokeMethod('updateRoute', {
        'viewId': id,
        'segments': segments
            .where((s) => s.points.length >= 2)
            .map(
              (s) => {
                'points': s.points.map(_point).toList(),
                'congested': false,
              },
            )
            .toList(),
        'traveled': traveled.map(_point).toList(),
        'origin': _point(widget.origin),
        'destination': _point(widget.destination),
        if (widget.driverPosition != null)
          'driver': {
            ..._point(widget.driverPosition!),
            if (widget.driverHeading != null) 'bearing': widget.driverHeading,
            'navigationMode': widget.followDriver,
          },
      });
    } catch (_) {
      // Map surface may not be ready yet.
    }
  }

  Map<String, double> _point(LatLng p) => {
    'lat': p.latitude,
    'lng': p.longitude,
  };

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'com.example.uzita/neshan_map_view',
      creationParams: {'isDark': widget.isDark},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: const {},
    );
  }
}
