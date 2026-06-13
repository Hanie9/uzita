import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/utils/map_tile_config.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_progress.dart';
import 'package:uzita/utils/validated_network_tile_provider.dart';
import 'package:uzita/widgets/driver_heading_arrow.dart';
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
  final bool isDark;
  final int? traveledFromIndex;

  const DriverNavigationMap({
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

  @override
  Widget build(BuildContext context) {
    if (NeshanDriverMap.isSupported) {
      final map = NeshanDriverMap(
        routeCoordinates: routeCoordinates,
        routeSegments: routeSegments,
        origin: origin,
        destination: destination,
        driverPosition: driverPosition,
        driverHeading: driverHeading,
        followDriver: followDriver,
        isDark: isDark,
        traveledFromIndex: traveledFromIndex,
        showDriverMarker: !followDriver,
      );

      // Navigation mode: large center arrow; map rotates with bearing underneath.
      if (followDriver && driverPosition != null) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            map,
            const IgnorePointer(
              child: Align(
                alignment: Alignment(0, 0.22),
                child: DriverHeadingArrow(
                  headingDegrees: 0,
                  size: 72,
                  pulse: true,
                ),
              ),
            ),
          ],
        );
      }

      return map;
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
      traveledFromIndex: traveledFromIndex,
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
  final int? traveledFromIndex;

  const _FlutterDriverNavigationMap({
    required this.routeCoordinates,
    required this.routeSegments,
    required this.origin,
    required this.destination,
    this.driverPosition,
    this.driverHeading,
    this.followDriver = false,
    this.isDark = false,
    this.traveledFromIndex,
  });

  @override
  State<_FlutterDriverNavigationMap> createState() =>
      _FlutterDriverNavigationMapState();
}

class _FlutterDriverNavigationMapState
    extends State<_FlutterDriverNavigationMap> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  LatLng? _previousDriverPosition;
  bool _fittedInitialBounds = false;

  static const _routeBlue = Color(0xFF2563EB);
  static const _trafficRed = Color(0xFFDC2626);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FlutterDriverNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.driverPosition != null &&
        widget.driverPosition != oldWidget.driverPosition) {
      _previousDriverPosition = oldWidget.driverPosition;
      if (widget.followDriver) {
        _followDriver(widget.driverPosition!);
      }
    } else if (!widget.followDriver && !_fittedInitialBounds) {
      _fitRouteBounds();
    }
  }

  void _onMapReady() {
    if (widget.followDriver && widget.driverPosition != null) {
      _followDriver(widget.driverPosition!);
    } else {
      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    final points = <LatLng>[
      widget.origin,
      widget.destination,
      ...widget.routeCoordinates,
    ];
    if (points.isEmpty) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(40),
      ),
    );
    _fittedInitialBounds = true;
  }

  void _followDriver(LatLng position) {
    final zoom = _mapController.camera.zoom.clamp(15.5, 18.0);
    final bearing = widget.driverHeading ?? _movementBearing(position);
    if (bearing != null) {
      _mapController.moveAndRotate(position, zoom, bearing);
    } else {
      _mapController.move(position, zoom);
    }
  }

  double? _movementBearing(LatLng current) {
    final prev = _previousDriverPosition;
    if (prev == null) return null;
    if (_distance(prev, current) < 3) return null;
    return _distance.bearing(prev, current);
  }

  double? get _resolvedHeading {
    if (widget.driverPosition == null) return null;
    return resolveDriverHeading(
      position: widget.driverPosition!,
      deviceHeading: widget.driverHeading,
      previousPosition: _previousDriverPosition,
      routePolyline: _route,
    );
  }

  List<LatLng> get _route =>
      widget.routeCoordinates.isNotEmpty
      ? widget.routeCoordinates
      : [widget.origin, widget.destination];

  List<RouteMapSegment> get _drawSegments {
    if (_route.length >= 2) {
      return [RouteMapSegment(points: _route, congested: false)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final traveledIndex = widget.traveledFromIndex ?? 0;
    final traveled = traveledIndex > 0
        ? _route.sublist(0, traveledIndex.clamp(1, _route.length))
        : <LatLng>[];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.origin,
        initialZoom: 13,
        minZoom: 5,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: widget.followDriver
              ? InteractiveFlag.pinchZoom | InteractiveFlag.drag
              : InteractiveFlag.all,
        ),
        onMapReady: _onMapReady,
      ),
      children: [
        TileLayer(
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
                strokeWidth: 7,
              ),
            ],
          ),
        PolylineLayer(
          polylines: [
            for (final segment in _drawSegments)
              if (segment.points.length >= 2)
                Polyline(
                  points: segment.points,
                  color: segment.congested ? _trafficRed : _routeBlue,
                  strokeWidth: 8,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.origin,
              width: 36,
              height: 36,
              child: const _MapPin(color: Colors.green, icon: Icons.trip_origin),
            ),
            Marker(
              point: widget.destination,
              width: 36,
              height: 36,
              child: const _MapPin(
                color: Color(0xFFEA580C),
                icon: Icons.location_on,
              ),
            ),
            if (widget.driverPosition != null && !widget.followDriver)
              Marker(
                point: widget.driverPosition!,
                width: 56,
                height: 56,
                rotate: true,
                child: DriverHeadingArrow(
                  headingDegrees: _resolvedHeading,
                  size: 52,
                  pulse: false,
                ),
              ),
          ],
        ),
        if (widget.followDriver && widget.driverPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.driverPosition!,
                width: 80,
                height: 80,
                alignment: Alignment.center,
                child: const DriverHeadingArrow(
                  headingDegrees: 0,
                  size: 72,
                  pulse: true,
                ),
              ),
            ],
          ),
      ],
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
