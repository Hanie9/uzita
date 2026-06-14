import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/widgets/driver_map_controller.dart';
import 'package:uzita/widgets/neshan_static_route_map.dart';

/// Android overview map using Neshan static arc image (reliable in release).
class AndroidOverviewStaticMap extends StatefulWidget {
  final List<LatLng> routeCoordinates;
  final LatLng origin;
  final LatLng destination;
  final LatLng? overviewDestination;
  final LatLng? driverPosition;
  final bool isDark;
  final DriverMapController? controller;
  final ValueChanged<bool>? onCameraDetached;

  const AndroidOverviewStaticMap({
    super.key,
    required this.routeCoordinates,
    required this.origin,
    required this.destination,
    this.overviewDestination,
    this.driverPosition,
    this.isDark = false,
    this.controller,
    this.onCameraDetached,
  });

  @override
  State<AndroidOverviewStaticMap> createState() =>
      _AndroidOverviewStaticMapState();
}

class _AndroidOverviewStaticMapState extends State<AndroidOverviewStaticMap> {
  final TransformationController _transformController =
      TransformationController();
  bool _cameraMoved = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.bind(
      refitOverview: _resetView,
      resumeNavigation: _resumeNavigationAt,
    );
  }

  @override
  void didUpdateWidget(covariant AndroidOverviewStaticMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      widget.controller?.bind(
        refitOverview: _resetView,
        resumeNavigation: _resumeNavigationAt,
      );
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _resetView() async {
    if (!mounted) return;
    setState(() => _cameraMoved = false);
    _transformController.value = Matrix4.identity();
    widget.onCameraDetached?.call(false);
  }

  Future<void> _resumeNavigationAt(LatLng position, double? heading) async {
    await _resetView();
  }

  void _onUserInteraction() {
    if (_cameraMoved) return;
    setState(() => _cameraMoved = true);
    widget.onCameraDetached?.call(true);
  }

  NeshanLatLng _toNeshan(LatLng point) =>
      NeshanLatLng(latitude: point.latitude, longitude: point.longitude);

  @override
  Widget build(BuildContext context) {
    final from = widget.driverPosition ?? widget.origin;
    final to = widget.overviewDestination ?? widget.destination;

    return SizedBox.expand(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.85,
        maxScale: 4,
        onInteractionStart: (_) => _onUserInteraction(),
        child: NeshanStaticRouteMap(
          origin: _toNeshan(from),
          destination: _toNeshan(to),
          routeCoordinates: widget.routeCoordinates,
          driverPosition: widget.driverPosition,
          isDark: widget.isDark,
        ),
      ),
    );
  }
}
