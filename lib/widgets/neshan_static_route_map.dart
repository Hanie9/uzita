import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/neshan_static_map.dart';

/// Neshan static arc map with optional driver position overlay.
class NeshanStaticRouteMap extends StatefulWidget {
  final NeshanLatLng origin;
  final NeshanLatLng destination;
  final List<LatLng> routeCoordinates;
  final LatLng? driverPosition;
  final bool isDark;

  const NeshanStaticRouteMap({
    super.key,
    required this.origin,
    required this.destination,
    required this.routeCoordinates,
    this.driverPosition,
    this.isDark = false,
  });

  @override
  State<NeshanStaticRouteMap> createState() => _NeshanStaticRouteMapState();
}

class _NeshanStaticRouteMapState extends State<NeshanStaticRouteMap> {
  Uint8List? _imageBytes;
  bool _loadFailed = false;
  int _lastWidth = 0;
  int _lastHeight = 0;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _authToken = prefs.getString('token'));
  }

  @override
  void didUpdateWidget(covariant NeshanStaticRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin != widget.origin ||
        oldWidget.destination != widget.destination ||
        oldWidget.isDark != widget.isDark) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _load(box.size);
      }
    });
  }

  Future<void> _load(Size size) async {
    final width = size.width.clamp(200, 1200).round();
    final height = size.height.clamp(150, 800).round();
    if (width == _lastWidth && height == _lastHeight && _imageBytes != null) {
      return;
    }
    if (width == _lastWidth && height == _lastHeight && _loadFailed) {
      return;
    }
    _lastWidth = width;
    _lastHeight = height;

    try {
      final bytes = await fetchNeshanStaticArcImage(
        from: widget.origin,
        to: widget.destination,
        width: width,
        height: height,
        dark: widget.isDark,
        authToken: _authToken,
      );
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_imageBytes == null && !_loadFailed) {
          _load(size);
        }

        if (_loadFailed) {
          final l = AppLocalizations.of(context);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l?.driver_route_map_error ?? 'Could not load map',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.iranianGray),
              ),
            ),
          );
        }

        if (_imageBytes == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.lapisLazuli),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            if (widget.driverPosition != null)
              _DriverDot(
                position: driverOverlayOnArcMap(
                  size,
                  widget.routeCoordinates,
                  widget.driverPosition!,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DriverDot extends StatelessWidget {
  final Offset position;

  const _DriverDot({required this.position});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 10,
      top: position.dy - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.local_taxi, size: 12, color: Colors.white),
      ),
    );
  }
}
