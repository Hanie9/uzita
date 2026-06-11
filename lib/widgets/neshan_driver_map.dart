import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Neshan native [MapView] on Android (license in res/raw/neshan.license).
class NeshanDriverMap extends StatefulWidget {
  final List<LatLng> routeCoordinates;
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

  List<LatLng> get _route =>
      widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  @override
  void didUpdateWidget(covariant NeshanDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_viewId != null) {
      _syncOverlays();
      if (widget.followDriver && widget.driverPosition != null) {
        _moveCamera(
          widget.driverPosition!,
          zoom: 16.5,
          bearing: widget.driverHeading,
        );
      }
    }
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOverlays();
      if (widget.followDriver && widget.driverPosition != null) {
        _moveCamera(
          widget.driverPosition!,
          zoom: 16.5,
          bearing: widget.driverHeading,
        );
      } else if (!_fitted) {
        _fitBounds();
      }
    });
  }

  Future<void> _fitBounds() async {
    final id = _viewId;
    if (id == null) return;
    await _channel.invokeMethod('fitBounds', {
      'viewId': id,
      'points': _route.map(_point).toList(),
    });
    _fitted = true;
  }

  Future<void> _moveCamera(
    LatLng position, {
    required double zoom,
    double? bearing,
  }) async {
    final id = _viewId;
    if (id == null) return;
    await _channel.invokeMethod('moveCamera', {
      'viewId': id,
      'lat': position.latitude,
      'lng': position.longitude,
      'zoom': zoom,
      if (bearing != null) 'bearing': bearing,
    });
  }

  Future<void> _syncOverlays() async {
    final id = _viewId;
    if (id == null) return;

    final traveledIndex = widget.traveledFromIndex ?? 0;
    final traveled = traveledIndex > 0
        ? _route.sublist(0, traveledIndex.clamp(1, _route.length))
        : <LatLng>[];
    final remaining = traveledIndex > 0
        ? _route.sublist(traveledIndex.clamp(0, _route.length - 1))
        : _route;

    await _channel.invokeMethod('updateRoute', {
      'viewId': id,
      'remaining': remaining.map(_point).toList(),
      'traveled': traveled.map(_point).toList(),
      'origin': _point(widget.origin),
      'destination': _point(widget.destination),
      if (widget.driverPosition != null)
        'driver': _point(widget.driverPosition!),
    });
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
