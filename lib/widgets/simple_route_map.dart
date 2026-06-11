import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/services.dart';

/// In-app route map drawn from polyline coordinates — no external map API.
class SimpleRouteMap extends StatelessWidget {
  final List<LatLng> routeCoordinates;
  final LatLng origin;
  final LatLng destination;
  final LatLng? driverPosition;
  final bool isDark;

  const SimpleRouteMap({
    super.key,
    required this.routeCoordinates,
    required this.origin,
    required this.destination,
    this.driverPosition,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isDark ? const Color(0xFF1A2332) : const Color(0xFFE8EEF4),
      child: CustomPaint(
        painter: _RouteMapPainter(
          routeCoordinates: routeCoordinates,
          origin: origin,
          destination: destination,
          driverPosition: driverPosition,
          isDark: isDark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final List<LatLng> routeCoordinates;
  final LatLng origin;
  final LatLng destination;
  final LatLng? driverPosition;
  final bool isDark;

  _RouteMapPainter({
    required this.routeCoordinates,
    required this.origin,
    required this.destination,
    required this.driverPosition,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final points = routeCoordinates.isNotEmpty
        ? routeCoordinates
        : [origin, destination];

    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final latPad = math.max((maxLat - minLat) * 0.15, 0.02);
    final lngPad = math.max((maxLng - minLng) * 0.15, 0.02);
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;

    Offset toOffset(LatLng p) {
      final x = lngSpan == 0 ? 0.5 : (p.longitude - minLng) / lngSpan;
      final y = latSpan == 0 ? 0.5 : (maxLat - p.latitude) / latSpan;
      const margin = 24.0;
      return Offset(
        margin + x * (size.width - margin * 2),
        margin + y * (size.height - margin * 2),
      );
    }

    final routePaint = Paint()
      ..color = AppColors.lapisLazuli
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = ui.Path()
      ..moveTo(toOffset(points.first).dx, toOffset(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final o = toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, routePaint);

    _drawMarker(canvas, toOffset(origin), Colors.green);
    _drawMarker(canvas, toOffset(destination), Colors.red);

    if (driverPosition != null) {
      _drawMarker(canvas, toOffset(driverPosition!), Colors.orange, radius: 9);
    }
  }

  void _drawMarker(
    Canvas canvas,
    Offset center,
    Color color, {
    double radius = 11,
  }) {
    canvas.drawCircle(center, radius + 2, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) {
    return oldDelegate.routeCoordinates != routeCoordinates ||
        oldDelegate.driverPosition != driverPosition ||
        oldDelegate.isDark != isDark;
  }
}
