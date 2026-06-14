import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/widgets/driver_map_controller.dart';
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
  final bool overviewMode;
  final bool pickupLeg;
  final int? traveledFromIndex;
  final String returnToRouteLabel;
  final DriverMapController? controller;
  final ValueChanged<bool>? onCameraDetached;

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
    this.overviewMode = false,
    this.pickupLeg = false,
    this.traveledFromIndex,
    this.returnToRouteLabel = 'Return to route',
    this.controller,
    this.onCameraDetached,
  });

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static const navZoom = 19.0;
  static const navTilt = 62.0;

  @override
  State<NeshanDriverMap> createState() => _NeshanDriverMapState();
}

class _NeshanDriverMapState extends State<NeshanDriverMap> {
  static const _channel = MethodChannel('com.example.uzita/neshan_map');
  static const _events = EventChannel('com.example.uzita/neshan_map_events');

  int? _viewId;
  bool _fitted = false;
  bool _mapUpdatePending = false;
  bool _autoFollow = true;
  LatLng? _previousDriverPosition;
  StreamSubscription<dynamic>? _mapEventSub;

  List<LatLng> get _route => widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  List<LatLng> get _fitPoints {
    if (widget.overviewMode) {
      final points = <LatLng>[
        widget.destination,
        if (widget.driverPosition != null) widget.driverPosition!,
        ..._route,
      ];
      return points;
    }
    return <LatLng>[
      widget.origin,
      widget.destination,
      if (widget.driverPosition != null) widget.driverPosition!,
      ..._route,
    ];
  }

  bool get _isNavigationMode => widget.followDriver;

  bool get _shouldFollowDriver =>
      _isNavigationMode && _autoFollow && widget.driverPosition != null;

  List<RouteMapSegment> get _displaySegments {
    final traveledIndex = widget.traveledFromIndex ?? 0;

    if (_isNavigationMode &&
        traveledIndex > 0 &&
        _route.length > traveledIndex) {
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
  void initState() {
    super.initState();
    _mapEventSub = _events.receiveBroadcastStream().listen(_onMapEvent);
    widget.controller?.bind(
      refitOverview: _refitOverview,
      resumeNavigation: _resumeNavigationAt,
    );
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _mapEventSub?.cancel();
    super.dispose();
  }

  void _onMapEvent(dynamic event) {
    if (event is! Map) return;
    final eventViewId = event['viewId'];
    if (eventViewId is int && _viewId != null && eventViewId != _viewId) return;
    if (!mounted) return;

    final type = event['type'];
    if (type == 'userCameraGesture') {
      if (!widget.followDriver) return;
      setState(() => _autoFollow = false);
      widget.onCameraDetached?.call(true);
      return;
    }
    if (type == 'overviewCameraGesture') {
      if (widget.followDriver || !widget.overviewMode) return;
      widget.onCameraDetached?.call(true);
    }
  }

  @override
  void didUpdateWidget(covariant NeshanDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      widget.controller?.bind(
        refitOverview: _refitOverview,
        resumeNavigation: _resumeNavigationAt,
      );
    }

    if (!oldWidget.followDriver && widget.followDriver) {
      _autoFollow = true;
      _fitted = false;
      if (_viewId != null && widget.driverPosition != null) {
        _scheduleMapUpdate(refit: true);
      }
    }
    if (oldWidget.followDriver && !widget.followDriver) {
      _fitted = false;
    }

    if (_viewId == null) return;

    final driverMoved =
        widget.driverPosition != oldWidget.driverPosition ||
        widget.driverHeading != oldWidget.driverHeading;
    if (widget.driverPosition != null &&
        widget.driverPosition != oldWidget.driverPosition) {
      _previousDriverPosition = oldWidget.driverPosition;
    }
    final followChanged = widget.followDriver != oldWidget.followDriver;
    final overviewChanged = widget.overviewMode != oldWidget.overviewMode;
    final themeChanged = widget.isDark != oldWidget.isDark;
    final routeChanged =
        widget.routeCoordinates.length != oldWidget.routeCoordinates.length ||
        widget.origin != oldWidget.origin ||
        widget.destination != oldWidget.destination;

    if (routeChanged || followChanged || overviewChanged) {
      _fitted = false;
    }
    if (widget.overviewMode && driverMoved) {
      _fitted = false;
    }

    if (driverMoved ||
        followChanged ||
        overviewChanged ||
        routeChanged ||
        themeChanged ||
        !_fitted) {
      final overviewNeedsRefit = widget.overviewMode && driverMoved;
      _scheduleMapUpdate(
        refit:
            overviewChanged ||
            routeChanged ||
            followChanged ||
            !_fitted ||
            overviewNeedsRefit,
      );
    }
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final delayMs = widget.followDriver ? 120 : 450;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted || _viewId == null) return;
      if (_shouldFollowDriver && widget.driverPosition != null) {
        await _resumeNavigationAt(
          widget.driverPosition!,
          widget.driverHeading,
        );
      } else {
        await _scheduleMapUpdate(refit: true);
      }
    });
  }

  Future<void> _resumeNavigationAt(LatLng position, double? heading) async {
    if (_viewId == null) return;
    setState(() {
      _autoFollow = true;
    });
    widget.onCameraDetached?.call(false);
    await _setNavigationFollow(true);
    await _syncOverlays();
    await _moveNavigationCamera(
      position,
      heading: _bearingForNavigation(position, heading),
    );
  }

  double? _bearingForNavigation(LatLng position, double? heading) {
    if (heading != null) return heading;
    return resolveDriverHeading(
      position: position,
      deviceHeading: widget.driverHeading,
      previousPosition: _previousDriverPosition,
      routePolyline: _route,
    );
  }

  Future<void> _moveNavigationCamera(
    LatLng position, {
    double? heading,
  }) async {
    final resolvedHeading =
        heading ?? _bearingForNavigation(position, null) ?? 0.0;
    await _moveCamera(
      position,
      zoom: NeshanDriverMap.navZoom,
      bearing: resolvedHeading,
      navigation: true,
      tilt: NeshanDriverMap.navTilt,
    );
  }

  Future<void> _refitOverview() async {
    if (_viewId == null) return;
    setState(() {
      _fitted = false;
    });
    widget.onCameraDetached?.call(false);
    await _setOverviewGestures(true);
    await _fitBounds();
  }

  Future<void> _setOverviewGestures(bool enabled) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('setOverviewGestures', {
        'viewId': id,
        'enabled': enabled,
      });
    } catch (_) {}
  }

  Future<void> _setNavigationFollow(bool enabled) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('setNavigationFollow', {
        'viewId': id,
        'enabled': enabled,
      });
    } catch (_) {}
  }

  Future<void> _scheduleMapUpdate({required bool refit}) async {
    if (_viewId == null || _mapUpdatePending) return;
    _mapUpdatePending = true;

    try {
      await _syncOverlays();
      if (!mounted || _viewId == null) return;

      if (_shouldFollowDriver) {
        await _setNavigationFollow(true);
        await _setOverviewGestures(false);
        await _moveNavigationCamera(
          widget.driverPosition!,
          heading: _bearingForNavigation(
            widget.driverPosition!,
            widget.driverHeading,
          ),
        );
      } else if (_isNavigationMode) {
        await _setNavigationFollow(false);
        await _setOverviewGestures(false);
      } else if (refit || !_fitted) {
        await _setNavigationFollow(false);
        await _setOverviewGestures(widget.overviewMode);
        await _fitBounds();
      } else {
        await _setNavigationFollow(false);
        await _setOverviewGestures(widget.overviewMode);
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
        'overview': widget.overviewMode,
      });
      _fitted = true;
    } catch (_) {
      await _moveCamera(widget.origin, zoom: 12, navigation: false);
      _fitted = true;
    }
  }

  Future<void> _moveCamera(
    LatLng position, {
    required double zoom,
    double? bearing,
    bool navigation = false,
    double? tilt,
  }) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('moveCamera', {
        'viewId': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'zoom': zoom,
        'navigation': navigation,
        if (bearing != null) 'bearing': bearing,
        if (tilt != null) 'tilt': tilt,
      });
    } catch (_) {}
  }

  Future<void> _syncOverlays() async {
    final id = _viewId;
    if (id == null) return;

    final traveledIndex = widget.traveledFromIndex ?? 0;
    final traveled = _isNavigationMode && traveledIndex > 0
        ? _route.sublist(0, traveledIndex.clamp(1, _route.length))
        : <LatLng>[];

    try {
      await _channel.invokeMethod('updateRoute', {
        'viewId': id,
        'mapDark': widget.isDark,
        'overviewMode': widget.overviewMode || !_isNavigationMode,
        'pickupLeg': widget.pickupLeg,
        'segments': _displaySegments
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
            'navigationMode': _isNavigationMode,
            'overviewMode': widget.overviewMode || !_isNavigationMode,
          },
      });
    } catch (_) {}
  }

  Map<String, double> _point(LatLng p) => {
    'lat': p.latitude,
    'lng': p.longitude,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AndroidView(
        viewType: 'com.example.uzita/neshan_map_view',
        creationParams: {'isDark': widget.isDark},
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
    );
  }
}
