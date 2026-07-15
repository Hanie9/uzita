import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/widgets/driver_map_controller.dart';
import 'package:uzita/utils/navigation_bearing.dart';
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
  final bool navigationMode;
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
    this.navigationMode = false,
    this.isDark = false,
    this.overviewMode = false,
    this.pickupLeg = false,
    this.traveledFromIndex,
    this.returnToRouteLabel = 'Return to route',
    this.controller,
    this.onCameraDetached,
  });

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static const navZoom = 17.5;
  /// Matches [NeshanMapPlugin] NAV_TILT (Carto: 0 = horizon, 90 = top-down).
  static const navTilt = 54.0;
  /// Matches [NeshanMapPlugin] NAV_FOCUS_OFFSET — native puck lower-third.
  static const navFocusOffset = 0.30;
  static const overviewIdleRefitDuration = Duration(seconds: 10);

  @override
  State<NeshanDriverMap> createState() => _NeshanDriverMapState();
}

class _NeshanDriverMapState extends State<NeshanDriverMap> {
  static const _channel = MethodChannel('com.example.uzita/neshan_map');
  static const _events = EventChannel('com.example.uzita/neshan_map_events');

  /// Max distance (m) the driver can be from the route and still be snapped
  /// onto it. Larger deviations are treated as off-route (handled by reroute).
  static const double _maxSnapMeters = 45;
  static const double _overlayResyncMinMeters = 28;
  static const double _cameraBearingMinDelta = 8;
  static const Duration _cameraUpdateMinInterval = Duration(milliseconds: 380);

  int? _viewId;
  bool _fitted = false;
  bool _mapUpdatePending = false;
  bool _mapUpdateQueued = false;
  bool _pendingRefit = false;
  bool _pendingForceOverlaySync = false;
  LatLng? _pendingNavPosition;
  double? _pendingNavHeading;
  bool _autoFollow = true;
  bool _overviewCameraDetached = false;
  bool _navigationCameraReady = false;
  LatLng? _previousDriverPosition;
  LatLng? _lastOverlaySyncPosition;
  int _lastOverlayRouteSegment = -1;
  double? _lastCameraBearing;
  double? _lastNavBearing;
  int? _lockedRouteSegmentIndex;
  DateTime? _lastCameraUpdateAt;
  Offset? _navPointerStart;
  bool _navPointerDetached = false;
  StreamSubscription<dynamic>? _mapEventSub;
  Timer? _overviewIdleRefitTimer;

  List<LatLng> get _route => widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  /// Polyline used for heading-up bearing (trimmed to the road ahead).
  List<LatLng> get _navigationPolyline {
    final segments = _displaySegments;
    if (segments.isEmpty) return _route;

    final points = <LatLng>[];
    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      if (points.isEmpty) {
        points.addAll(segment.points);
        continue;
      }
      final first = segment.points.first;
      if (points.last.latitude == first.latitude &&
          points.last.longitude == first.longitude) {
        points.addAll(segment.points.sublist(1));
      } else {
        points.addAll(segment.points);
      }
    }
    return points.length >= 2 ? points : _route;
  }

  List<LatLng> get _fitPoints {
    final points = <LatLng>[
      widget.origin,
      widget.destination,
      if (widget.driverPosition != null) widget.driverPosition!,
    ];
    if (_route.length >= 2) {
      points.add(_route.first);
      if (_route.length > 2) {
        points.add(_route[_route.length ~/ 2]);
      }
      points.add(_route.last);
    }
    return points;
  }

  bool get _isNavigationMode => widget.navigationMode;

  bool get _shouldFollowDriver =>
      _isNavigationMode &&
      widget.followDriver &&
      _autoFollow &&
      widget.driverPosition != null;

  List<RouteMapSegment> get _displaySegments {
    if (_isNavigationMode &&
        widget.driverPosition != null &&
        _route.length >= 2) {
      final segments = widget.routeSegments;
      if (segments.isNotEmpty) {
        final trimmed = RouteMapGeometry.trimSegmentsFromDriver(
          segments: segments,
          fullPolyline: _route,
          driver: _snapNavPosition(widget.driverPosition!),
        );
        if (trimmed.isNotEmpty) return trimmed;
      }
      return [_navigationAheadSegment(_snapNavPosition(widget.driverPosition!))];
    }

    final segments = widget.routeSegments;
    if (segments.isNotEmpty) return segments;

    if (_route.length >= 2) {
      return [RouteMapSegment(points: _route)];
    }
    return const [];
  }

  RouteMapSegment _navigationAheadSegment(LatLng snapped) {
    final ahead = polylineAheadOf(_route, snapped);
    final points = ahead.length >= 2 ? ahead : _route;
    return RouteMapSegment(
      points: points,
      trafficLevel: _trafficLevelNear(snapped),
    );
  }

  RouteTrafficLevel _trafficLevelNear(LatLng snapped) {
    for (final segment in widget.routeSegments) {
      if (segment.points.length < 2) continue;
      if (distanceToPolylineMeters(segment.points, snapped) <= 55) {
        return segment.trafficLevel;
      }
    }
    return RouteTrafficLevel.clear;
  }

  int get _traveledSliceEnd {
    if (!_isNavigationMode ||
        widget.driverPosition == null ||
        _route.length < 2) {
      return 0;
    }
    final snapped = snapPointToPolyline(_route, widget.driverPosition!);
    final index = findClosestPolylineIndex(_route, snapped);
    return (index + 1).clamp(1, _route.length);
  }

  List<LatLng> get _traveledPolyline {
    if (_shouldFollowDriver) return const [];
    if (!_isNavigationMode ||
        widget.driverPosition == null ||
        _route.length < 2) {
      return const [];
    }
    final traveledIndex = _traveledSliceEnd;
    if (traveledIndex <= 1) return const [];

    final snapped = snapPointToPolyline(_route, widget.driverPosition!);
    final head = _route.sublist(0, traveledIndex);
    if (head.isEmpty) return const [];
    return [...head, snapped];
  }

  @override
  void initState() {
    super.initState();
    _mapEventSub = _events.receiveBroadcastStream().listen(_onMapEvent);
    widget.controller?.bind(
      refitOverview: _refitOverview,
      resumeNavigation: _resumeNavigationAt,
      tickNavigation: _tickNavigationAt,
    );
  }

  @override
  void dispose() {
    _cancelOverviewIdleRefit();
    widget.controller?.unbind();
    _mapEventSub?.cancel();
    super.dispose();
  }

  void _cancelOverviewIdleRefit() {
    _overviewIdleRefitTimer?.cancel();
    _overviewIdleRefitTimer = null;
  }

  void _scheduleOverviewIdleRefit() {
    _cancelOverviewIdleRefit();
    if (!widget.overviewMode || widget.navigationMode) return;
    _overviewIdleRefitTimer = Timer(NeshanDriverMap.overviewIdleRefitDuration, () {
      if (!mounted || !_overviewCameraDetached) return;
      unawaited(_refitOverview());
    });
  }

  void _onOverviewCameraInteraction() {
    if (!widget.overviewMode || widget.navigationMode) return;
    if (!_overviewCameraDetached) {
      setState(() => _overviewCameraDetached = true);
      widget.onCameraDetached?.call(true);
    }
    _scheduleOverviewIdleRefit();
  }

  void _onMapEvent(dynamic event) {
    if (event is! Map) return;
    final eventViewId = event['viewId'];
    if (eventViewId is int && _viewId != null && eventViewId != _viewId) return;
    if (!mounted) return;

    final type = event['type'];
    if (type == 'userCameraGesture') {
      if (!widget.navigationMode) return;
      _detachFromRoute();
      return;
    }
    if (type == 'overviewCameraGesture') {
      if (widget.navigationMode) return;
      if (!widget.overviewMode) return;
      _onOverviewCameraInteraction();
    }
  }

  void _detachFromRoute() {
    if (!_autoFollow) {
      _showDetachedDriverMarker();
      return;
    }
    setState(() => _autoFollow = false);
    widget.onCameraDetached?.call(true);
    unawaited(_setNavigationFollow(false).then((_) => _showDetachedDriverMarker()));
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.overviewMode && !widget.navigationMode) {
      _onOverviewCameraInteraction();
    }
    if (!widget.navigationMode) return;
    _navPointerStart = event.localPosition;
    _navPointerDetached = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.navigationMode || !_autoFollow || _navPointerDetached) return;
    final start = _navPointerStart;
    if (start == null) return;
    if ((event.localPosition - start).distance < 10) return;

    _navPointerDetached = true;
    _detachFromRoute();
  }

  void _onPointerEnd(PointerEvent event) {
    _navPointerStart = null;
    _navPointerDetached = false;
  }

  Future<void> _showDetachedDriverMarker() async {
    final pos = widget.driverPosition;
    if (pos == null || !_isNavigationMode) return;
    final navPos = _snapNavPosition(pos);
    await _syncOverlays();
    await _updateDriverMarkerOnly(navPos, widget.driverHeading);
  }

  @override
  void didUpdateWidget(covariant NeshanDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      widget.controller?.bind(
        refitOverview: _refitOverview,
        resumeNavigation: _resumeNavigationAt,
        tickNavigation: _tickNavigationAt,
      );
    }

    if ((!oldWidget.followDriver && widget.followDriver) ||
        (!oldWidget.navigationMode && widget.navigationMode)) {
      _autoFollow = true;
      _overviewCameraDetached = false;
      _fitted = true;
      _navigationCameraReady = false;
      if (_viewId != null && widget.driverPosition != null) {
        unawaited(
          _resumeNavigationAt(widget.driverPosition!, widget.driverHeading),
        );
      } else if (widget.driverPosition != null) {
        _pendingNavPosition = widget.driverPosition;
        _pendingNavHeading = widget.driverHeading;
      }
      return;
    }
    if ((oldWidget.followDriver && !widget.followDriver) ||
        (oldWidget.navigationMode && !widget.navigationMode)) {
      _fitted = false;
      _navigationCameraReady = false;
    }
    if (oldWidget.overviewMode && !widget.overviewMode) {
      _cancelOverviewIdleRefit();
    }

    if (_viewId == null) return;

    final positionChanged = widget.driverPosition != oldWidget.driverPosition;
    final headingChanged = widget.driverHeading != oldWidget.driverHeading;
    if (widget.driverPosition != null && positionChanged) {
      _previousDriverPosition = oldWidget.driverPosition;
    }
    final followChanged = widget.followDriver != oldWidget.followDriver;
    final navigationModeChanged =
        widget.navigationMode != oldWidget.navigationMode;
    final overviewChanged = widget.overviewMode != oldWidget.overviewMode;
    final themeChanged = widget.isDark != oldWidget.isDark;
    final routeChanged =
        !listEquals(widget.routeCoordinates, oldWidget.routeCoordinates) ||
        !listEquals(widget.routeSegments, oldWidget.routeSegments) ||
        widget.origin != oldWidget.origin ||
        widget.destination != oldWidget.destination ||
        widget.pickupLeg != oldWidget.pickupLeg;
    final structuralChanged = routeChanged ||
        followChanged ||
        navigationModeChanged ||
        overviewChanged ||
        themeChanged;

    if (routeChanged ||
        followChanged ||
        navigationModeChanged ||
        overviewChanged) {
      _fitted = false;
      _lastOverlaySyncPosition = null;
      if (routeChanged &&
          _isNavigationMode &&
          widget.driverPosition != null &&
          _navigationCameraReady) {
        _lockedRouteSegmentIndex = routeSegmentIndexForPosition(
          _route,
          _snapNavPosition(widget.driverPosition!),
        );
      }
    }
    if (widget.overviewMode && positionChanged && !_overviewCameraDetached) {
      final prev = oldWidget.driverPosition;
      final next = widget.driverPosition;
      if (prev != null && next != null && distanceMeters(prev, next) > 800) {
        _fitted = false;
      }
    }

    if (structuralChanged || !_fitted) {
      _scheduleMapUpdate(
        refit:
            overviewChanged ||
            routeChanged ||
            followChanged ||
            navigationModeChanged ||
            (!_fitted && !_overviewCameraDetached),
        forceOverlaySync: structuralChanged,
      );
      return;
    }

    if (positionChanged && widget.driverPosition != null) {
      // Live GPS updates are handled by [tickNavigation] — avoid double camera
      // moves that make the map jump.
      if (_isNavigationMode && widget.followDriver) {
        return;
      }
      final navPos = _isNavigationMode
          ? _snapNavPosition(widget.driverPosition!)
          : widget.driverPosition!;
      unawaited(_applyNavigationUpdate(navPos, widget.driverHeading));
      return;
    }

    if (headingChanged &&
        widget.navigationMode &&
        widget.followDriver &&
        widget.driverPosition != null) {
      return;
    }
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final delayMs = widget.navigationMode ? 120 : 100;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted || _viewId == null) return;
      final pending = _pendingNavPosition;
      final pendingHeading = _pendingNavHeading;
      if (pending != null) {
        _pendingNavPosition = null;
        _pendingNavHeading = null;
        await _resumeNavigationAt(pending, pendingHeading);
        return;
      }
      if (_shouldFollowDriver && widget.driverPosition != null) {
        await _resumeNavigationAt(widget.driverPosition!, widget.driverHeading);
      } else {
        await _scheduleMapUpdate(refit: true);
      }
    });
  }

  Future<void> _resumeNavigationAt(LatLng position, double? heading) async {
    if (_viewId == null) {
      _pendingNavPosition = position;
      _pendingNavHeading = heading;
      return;
    }
    if (!_autoFollow) {
      setState(() => _autoFollow = true);
    }
    widget.onCameraDetached?.call(false);

    final navPos = _snapNavPosition(position);
    final resolvedHeading = _navHeading(navPos, heading);

    await _setNavigationFollow(true);
    await _setOverviewGestures(false);
    _lastOverlaySyncPosition = null;
    _lastNavBearing = null;
    _lastCameraBearing = null;
    _lockedRouteSegmentIndex = null;
    _lastOverlayRouteSegment = -1;
    await _beginNavigationCamera(navPos, resolvedHeading);
    await _syncOverlays();
    _markOverlaySynced(navPos);
    _navigationCameraReady = true;
  }

  Future<void> _tickNavigationAt(LatLng position, double? heading) async {
    if (_viewId == null) return;

    final navPos = _snapNavPosition(position);
    await _applyNavigationUpdate(navPos, heading);

    if (!_autoFollow || !widget.followDriver) return;
    final resolvedHeading = _navHeading(navPos, heading);
    await _followNavigationCameraThrottled(navPos, resolvedHeading);
  }

  Future<void> _applyNavigationUpdate(LatLng navPos, double? heading) async {
    if (_shouldResyncOverlays(navPos)) {
      await _syncOverlays();
      _markOverlaySynced(navPos);
    } else if (_isNavigationMode) {
      await _updateDriverMarkerOnly(navPos, heading);
    }
  }

  bool _shouldResyncOverlays(LatLng navPos) {
    final last = _lastOverlaySyncPosition;
    final routeSegment = routeSegmentIndexForPosition(_route, navPos) ?? -1;
    if (last == null) return true;
    if (routeSegment != _lastOverlayRouteSegment) return true;
    if (distanceMeters(last, navPos) >= _overlayResyncMinMeters) return true;
    return false;
  }

  void _markOverlaySynced(LatLng navPos) {
    _lastOverlaySyncPosition = navPos;
    _lastOverlayRouteSegment = routeSegmentIndexForPosition(_route, navPos) ?? -1;
  }

  Future<void> _updateDriverMarkerOnly(LatLng navPos, double? heading) async {
    final id = _viewId;
    if (id == null) return;
    final bearing = _navHeading(navPos, heading);
    try {
      await _channel.invokeMethod('updateDriverMarker', {
        'viewId': id,
        'lat': navPos.latitude,
        'lng': navPos.longitude,
        'bearing': bearing,
        'navigationMode': _isNavigationMode,
      });
    } catch (_) {}
  }

  Future<void> _followNavigationCameraThrottled(
    LatLng position,
    double bearing,
  ) async {
    final now = DateTime.now();
    final lastAt = _lastCameraUpdateAt;
    final lastBearing = _lastCameraBearing;
    final lastPos = _lastOverlaySyncPosition;
    if (lastAt != null &&
        lastBearing != null &&
        lastPos != null &&
        now.difference(lastAt) < _cameraUpdateMinInterval &&
        bearingDeltaDegrees(lastBearing, bearing) < _cameraBearingMinDelta &&
        distanceMeters(lastPos, position) < 2.5) {
      return;
    }
    _lastCameraUpdateAt = now;
    _lastCameraBearing = bearing;
    await _followNavigationCamera(position, bearing);
  }

  /// Snaps the raw GPS position onto the planned route so the driver arrow
  /// always sits exactly on the displayed line (like a navigation app). Only
  /// snaps when reasonably close; large deviations are left to the re-router.
  LatLng _snapNavPosition(LatLng raw) {
    if (!_isNavigationMode || _route.length < 2) return raw;
    final snapped = snapPointToPolyline(_route, raw);
    return distanceMeters(raw, snapped) <= _maxSnapMeters ? snapped : raw;
  }

  /// Heading-up: stable bearing locked to route segment (updates only at turns).
  double _navHeading(LatLng navPos, double? heading) {
    if (!_isNavigationMode) {
      final resolved = resolveNavigationBearing(
        position: navPos,
        deviceHeading: heading ?? widget.driverHeading,
        previousPosition: _previousDriverPosition,
        routePolyline: _navigationPolyline,
        navigationActive: false,
        lastKnownBearing: _lastNavBearing,
      );
      return _rememberNavBearing(resolved) ??
          _bearingForNavigation(navPos, heading) ??
          0.0;
    }

    final segmentIndex = resolveLockedRouteSegmentIndex(
      _route,
      navPos,
      _lockedRouteSegmentIndex,
    );
    final locked = resolveRouteLockedNavigationBearing(
      position: navPos,
      routePolyline: _route,
      lastKnownBearing: _lastNavBearing,
      lastRouteSegmentIndex: _lockedRouteSegmentIndex,
    );
    _lockedRouteSegmentIndex = segmentIndex;
    if (locked != null) {
      _lastNavBearing = locked;
      return locked;
    }

    return _lastNavBearing ?? heading ?? widget.driverHeading ?? 0.0;
  }

  double? _rememberNavBearing(double? bearing) {
    if (bearing != null) {
      _lastNavBearing = bearing;
    }
    return bearing;
  }

  Future<void> _beginNavigationCamera(LatLng position, double bearing) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('beginNavigationCamera', {
        'viewId': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'bearing': bearing,
        'mapDark': widget.isDark,
      });
    } catch (_) {
      await _setNavigationFollow(true);
      await _setOverviewGestures(false);
      await _moveNavigationCamera(position, heading: bearing);
    }
  }

  Future<void> _updateNavigationCamera(LatLng position, double bearing) async {
    final id = _viewId;
    if (id == null) return;
    try {
      await _channel.invokeMethod('updateNavigationCamera', {
        'viewId': id,
        'lat': position.latitude,
        'lng': position.longitude,
        'bearing': bearing,
      });
    } catch (_) {
      await _moveNavigationCamera(position, heading: bearing);
    }
  }

  Future<void> _followNavigationCamera(LatLng position, double? heading) async {
    final resolvedHeading =
        heading ?? _bearingForNavigation(position, heading) ?? 0.0;
    if (_navigationCameraReady) {
      await _updateNavigationCamera(position, resolvedHeading);
    } else {
      await _beginNavigationCamera(position, resolvedHeading);
      _navigationCameraReady = true;
    }
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

  Future<void> _moveNavigationCamera(LatLng position, {double? heading}) async {
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
    _cancelOverviewIdleRefit();
    setState(() {
      _fitted = false;
      _overviewCameraDetached = false;
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

  Future<void> _scheduleMapUpdate({
    required bool refit,
    bool forceOverlaySync = false,
  }) async {
    if (_viewId == null) return;
    // Accumulate refit requests so a queued update never loses the refit
    // intent (otherwise a freshly-loaded route may never be re-framed).
    if (refit) _pendingRefit = true;
    if (forceOverlaySync) _pendingForceOverlaySync = true;
    if (_mapUpdatePending) {
      _mapUpdateQueued = true;
      return;
    }
    _mapUpdatePending = true;
    final doRefit = _pendingRefit;
    final doForceOverlaySync = _pendingForceOverlaySync;
    _pendingRefit = false;
    _pendingForceOverlaySync = false;

    try {
      if (widget.driverPosition != null) {
        final navPos = _isNavigationMode
            ? _snapNavPosition(widget.driverPosition!)
            : widget.driverPosition!;
        if (doForceOverlaySync || _shouldResyncOverlays(navPos)) {
          await _syncOverlays();
          _markOverlaySynced(navPos);
        } else if (_isNavigationMode) {
          await _updateDriverMarkerOnly(navPos, widget.driverHeading);
        } else {
          await _syncOverlays();
          _markOverlaySynced(navPos);
        }
      } else {
        await _syncOverlays();
      }
      if (!mounted || _viewId == null) return;

      if (widget.navigationMode || widget.followDriver) {
        await _setOverviewGestures(false);
        if (widget.driverPosition != null && _autoFollow) {
          await _setNavigationFollow(true);
          // Live camera is driven only by [tickNavigation]. Route/traffic overlay
          // refreshes (every ~2 min) must not re-apply bearing — that jumps the map.
          if (!_navigationCameraReady) {
            final navPos = _snapNavPosition(widget.driverPosition!);
            final bearing = _navHeading(navPos, widget.driverHeading);
            await _beginNavigationCamera(navPos, bearing);
            _navigationCameraReady = true;
          }
        } else if (widget.navigationMode) {
          await _setNavigationFollow(false);
        }
        return;
      }

      if ((doRefit || !_fitted) && widget.overviewMode) {
        await _setNavigationFollow(false);
        await _setOverviewGestures(true);
        if (!_overviewCameraDetached) {
          await _fitBounds();
        }
      } else if (!widget.navigationMode) {
        await _setNavigationFollow(false);
        await _setOverviewGestures(widget.overviewMode);
      }
    } finally {
      _mapUpdatePending = false;
      if (_mapUpdateQueued) {
        _mapUpdateQueued = false;
        await _scheduleMapUpdate(
          refit: _pendingRefit,
          forceOverlaySync: _pendingForceOverlaySync,
        );
      }
    }
  }

  Future<void> _fitBounds() async {
    if (widget.followDriver || !widget.overviewMode) return;
    final id = _viewId;
    if (id == null) return;
    final points = _fitPoints;
    if (points.isEmpty) return;

    try {
      await _channel.invokeMethod('fitBounds', {
        'viewId': id,
        'points': points.map(_point).toList(),
        'overview': widget.overviewMode,
        if (widget.overviewMode) 'bottomInsetRatio': 0.12,
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

    final traveled = _traveledPolyline;
    final segments = compactSegmentsForMap(
      _displaySegments,
      navigationMode: _isNavigationMode,
    );

    try {
      await _channel.invokeMethod('updateRoute', {
        'viewId': id,
        'mapDark': widget.isDark,
        'overviewMode': !_isNavigationMode,
        'pickupLeg': widget.pickupLeg,
        'segments': segments
            .where((s) => s.points.length >= 2)
            .map(
              (s) => {
                'points': s.points.map(_point).toList(),
                'trafficLevel': s.trafficLevel.name,
              },
            )
            .toList(),
        'traveled': traveled.map(_point).toList(),
        'origin': _point(widget.origin),
        'destination': _point(widget.destination),
        if (widget.driverPosition != null)
          'driver': () {
            final navPos = _isNavigationMode
                ? _snapNavPosition(widget.driverPosition!)
                : widget.driverPosition!;
            final bearing = _isNavigationMode
                ? _navHeading(navPos, widget.driverHeading)
                : widget.driverHeading;
            return {
              ..._point(navPos),
              if (bearing != null) 'bearing': bearing,
              'navigationMode': _isNavigationMode,
              'overviewMode': !_isNavigationMode,
            };
          }(),
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
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: AndroidView(
          viewType: 'com.example.uzita/neshan_map_view',
          creationParams: {'isDark': widget.isDark},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}
