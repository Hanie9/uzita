import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/map_tile_config.dart';
import 'package:uzita/utils/neshan_route_style.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_progress.dart';
import 'package:uzita/utils/validated_network_tile_provider.dart';
import 'package:uzita/widgets/driver_heading_arrow.dart';
import 'package:uzita/widgets/driver_map_controller.dart';
import 'package:uzita/widgets/neshan_driver_map.dart';

/// Route map: Neshan [MapView] on Android, [FlutterMap] elsewhere.
class DriverNavigationMap extends StatelessWidget {
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

  const DriverNavigationMap({
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

  @override
  Widget build(BuildContext context) {
    if (NeshanDriverMap.isSupported) {
      return NeshanDriverMap(
        routeCoordinates: routeCoordinates,
        routeSegments: routeSegments,
        origin: origin,
        destination: destination,
        driverPosition: driverPosition,
        driverHeading: driverHeading,
        followDriver: followDriver,
        navigationMode: navigationMode,
        isDark: isDark,
        overviewMode: overviewMode,
        pickupLeg: pickupLeg,
        traveledFromIndex: traveledFromIndex,
        returnToRouteLabel: returnToRouteLabel,
        controller: controller,
        onCameraDetached: onCameraDetached,
      );
    }

    return _FlutterDriverNavigationMap(
      routeCoordinates: routeCoordinates,
      routeSegments: routeSegments,
      origin: origin,
      destination: destination,
      driverPosition: driverPosition,
      driverHeading: driverHeading,
      followDriver: followDriver,
      isDark: isDark,
      overviewMode: overviewMode,
      pickupLeg: pickupLeg,
      traveledFromIndex: traveledFromIndex,
      returnToRouteLabel: returnToRouteLabel,
      controller: controller,
      onCameraDetached: onCameraDetached,
    );
  }
}

class _FlutterDriverNavigationMap extends StatefulWidget {
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

  const _FlutterDriverNavigationMap({
    required this.routeCoordinates,
    required this.routeSegments,
    required this.origin,
    required this.destination,
    this.driverPosition,
    this.driverHeading,
    this.followDriver = false,
    this.isDark = false,
    this.overviewMode = false,
    this.pickupLeg = false,
    this.traveledFromIndex,
    required this.returnToRouteLabel,
    this.controller,
    this.onCameraDetached,
  });

  @override
  State<_FlutterDriverNavigationMap> createState() =>
      _FlutterDriverNavigationMapState();
}

class _FlutterDriverNavigationMapState
    extends State<_FlutterDriverNavigationMap> {
  final MapController _mapController = MapController();
  bool _fittedInitialBounds = false;
  bool _autoFollow = true;
  bool _overviewCameraDetached = false;
  bool _mapReady = false;
  Timer? _overviewIdleRefitTimer;

  static const _overviewIdleRefitDuration = Duration(seconds: 10);

  static Color _routeLineColor(RouteTrafficLevel level) =>
      NeshanRouteStyle.colorForTrafficLevel(level);

  @override
  void initState() {
    super.initState();
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
    _mapController.dispose();
    super.dispose();
  }

  void _cancelOverviewIdleRefit() {
    _overviewIdleRefitTimer?.cancel();
    _overviewIdleRefitTimer = null;
  }

  void _scheduleOverviewIdleRefit() {
    _cancelOverviewIdleRefit();
    if (!widget.overviewMode || widget.followDriver) return;
    _overviewIdleRefitTimer = Timer(_overviewIdleRefitDuration, () {
      if (!mounted || !_overviewCameraDetached) return;
      unawaited(_refitOverview());
    });
  }

  void _onOverviewMapInteraction() {
    if (!widget.overviewMode || widget.followDriver) return;
    if (!_overviewCameraDetached) {
      setState(() => _overviewCameraDetached = true);
      widget.onCameraDetached?.call(true);
    }
    _scheduleOverviewIdleRefit();
  }

  @override
  void didUpdateWidget(covariant _FlutterDriverNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      widget.controller?.bind(
        refitOverview: _refitOverview,
        resumeNavigation: _resumeNavigationAt,
        tickNavigation: _tickNavigationAt,
      );
    }

    if (!oldWidget.followDriver && widget.followDriver) {
      _autoFollow = true;
    }
    if (oldWidget.overviewMode && !widget.overviewMode) {
      _cancelOverviewIdleRefit();
    }

    final routeChanged =
        widget.routeCoordinates.length != oldWidget.routeCoordinates.length ||
        widget.origin != oldWidget.origin ||
        widget.destination != oldWidget.destination;

    if (routeChanged) {
      _fittedInitialBounds = false;
    }

    if (widget.driverPosition != null &&
        widget.driverPosition != oldWidget.driverPosition) {
      if (widget.followDriver && _autoFollow) {
        _followDriver(widget.driverPosition!);
      }
    } else if (!widget.followDriver &&
        !_overviewCameraDetached &&
        (!_fittedInitialBounds || routeChanged)) {
      _fitRouteBounds();
    }
  }

  void _onMapReady() {
    _mapReady = true;
    if (widget.followDriver && widget.driverPosition != null && _autoFollow) {
      _followDriver(widget.driverPosition!);
    } else {
      _fitRouteBounds();
    }
  }

  void _onUserMapInteraction() {
    if (!widget.followDriver) return;
    if (!_autoFollow) return;
    setState(() => _autoFollow = false);
    widget.onCameraDetached?.call(true);
  }

  Future<void> _resumeNavigationAt(LatLng position, double? heading) async {
    if (!_mapReady) return;
    setState(() => _autoFollow = true);
    widget.onCameraDetached?.call(false);
    _followDriverAt(position, heading);
  }

  Future<void> _tickNavigationAt(LatLng position, double? heading) async {
    if (!_mapReady || !_autoFollow || !widget.followDriver) return;
    _followDriverAt(position, heading);
  }

  Future<void> _refitOverview() async {
    _cancelOverviewIdleRefit();
    setState(() {
      _fittedInitialBounds = false;
      _overviewCameraDetached = false;
    });
    widget.onCameraDetached?.call(false);
    _fitRouteBounds();
  }

  void _fitRouteBounds() {
    if (!_mapReady) return;
    final points = <LatLng>[
      widget.origin,
      widget.destination,
      if (widget.driverPosition != null) widget.driverPosition!,
    ];
    final route = _route;
    if (route.length >= 2) {
      points.add(route.first);
      if (route.length > 2) points.add(route[route.length ~/ 2]);
      points.add(route.last);
    }
    if (points.isEmpty) return;

    final padding = widget.overviewMode
        ? const EdgeInsets.fromLTRB(48, 100, 48, 340)
        : const EdgeInsets.fromLTRB(40, 40, 40, 40);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: padding,
      ),
    );
    _fittedInitialBounds = true;
  }

  void _followDriverAt(LatLng position, double? heading) {
    const zoom = NeshanDriverMap.navZoom;
    final bearing = heading ?? widget.driverHeading;
    if (bearing != null) {
      _mapController.moveAndRotate(position, zoom, bearing);
    } else {
      _mapController.move(position, zoom);
    }
  }

  void _followDriver(LatLng position) {
    _followDriverAt(position, widget.driverHeading);
  }

  List<LatLng> get _route =>
      widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  List<RouteMapSegment> get _drawSegments {
    final segments = widget.routeSegments;
    if (segments.isNotEmpty) {
      if (widget.followDriver &&
          widget.driverPosition != null &&
          _route.length >= 2) {
        return RouteMapGeometry.trimSegmentsFromDriver(
          segments: segments,
          fullPolyline: _route,
          driver: widget.driverPosition!,
        );
      }
      return segments;
    }

    if (widget.followDriver &&
        widget.driverPosition != null &&
        _route.length >= 2) {
      final startIndex = findClosestPolylineIndex(
        _route,
        widget.driverPosition!,
      ).clamp(0, _route.length - 2);
      final remaining = _route.sublist(startIndex);
      if (remaining.length >= 2) {
        return [RouteMapSegment(points: remaining)];
      }
    }

    if (_route.length >= 2) {
      return [RouteMapSegment(points: _route)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final traveledIndex = widget.traveledFromIndex ?? 0;
    final traveled = traveledIndex > 0
        ? _route.sublist(0, traveledIndex.clamp(1, _route.length))
        : <LatLng>[];

    return ColoredBox(
      color: widget.isDark
          ? const Color(0xFF1A2332)
          : const Color(0xFFE8EEF4),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (widget.overviewMode && !widget.followDriver) {
            _onOverviewMapInteraction();
          }
        },
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.origin,
            initialZoom: 13,
            minZoom: 5,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: _onMapReady,
            onPositionChanged: (position, hasGesture) {
              if (!hasGesture) return;
              if (widget.followDriver) {
                _onUserMapInteraction();
              } else if (widget.overviewMode) {
                _onOverviewMapInteraction();
              }
            },
          ),
          children: [
            TileLayer(
              key: ValueKey(widget.isDark),
              urlTemplate: MapTileConfig.urlFor(isDark: widget.isDark),
              fallbackUrl: MapTileConfig.fallbackFor(isDark: widget.isDark),
              subdomains: MapTileConfig.cartoSubdomains,
              userAgentPackageName: MapTileConfig.userAgentPackageName,
              maxNativeZoom: 19,
              retinaMode: false,
              tileProvider: ValidatedNetworkTileProvider(),
              evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            ),
            if (traveled.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: traveled,
                    color: Colors.grey.withValues(alpha: 0.55),
                    strokeWidth: 5,
                  ),
                ],
              ),
            PolylineLayer(
              polylines: [
                for (final segment in _drawSegments)
                  if (segment.points.length >= 2)
                    Polyline(
                      points: segment.points,
                      color: _routeLineColor(segment.trafficLevel),
                      strokeWidth: widget.followDriver
                          ? NeshanRouteStyle.navigationLineWidth
                          : NeshanRouteStyle.overviewLineWidth,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (!widget.followDriver) ...[
                  if (!widget.pickupLeg)
                    Marker(
                      point: widget.origin,
                      width: 36,
                      height: 36,
                      child: const _MapPin(
                        color: Colors.green,
                        icon: Icons.trip_origin,
                      ),
                    ),
                  Marker(
                    point: widget.destination,
                    width: 36,
                    height: 36,
                    child: _MapPin(
                      color: widget.pickupLeg
                          ? Colors.green
                          : const Color(0xFFEA580C),
                      icon: widget.pickupLeg
                          ? Icons.trip_origin
                          : Icons.location_on,
                    ),
                  ),
                ],
            if (widget.driverPosition != null)
              Marker(
                point: widget.driverPosition!,
                width: widget.followDriver ? 44 : 20,
                height: widget.followDriver ? 48 : 20,
                alignment: Alignment.center,
                rotate: !widget.followDriver,
                child: widget.followDriver
                    ? const DriverHeadingArrow(
                        headingDegrees: 0,
                        size: 44,
                        pulse: false,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
              ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _MapPin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
