import 'package:flutter/material.dart';
import 'package:uzita/utils/route_map_geometry.dart';

/// Official Neshan route styling.
///
/// Matches the Neshan traffic-layer palette on the route line:
/// blue (خلوت), orange (روان), red (نیمه‌سنگین), dark red (سنگین).
abstract final class NeshanRouteStyle {
  /// Neshan Direction API draw-route colour (`#250ECD`) — free-flowing segments.
  static const Color routeLine = Color(0xFF250ECD);

  static const int routeLineArgb = 0xFF250ECD;

  /// Neshan traffic layer — smooth flowing (نارنجی / ترافیک روان).
  static const Color trafficSmooth = Color(0xFFFF9800);

  /// Neshan traffic layer — semi-heavy (قرمز).
  static const Color trafficModerate = Color(0xFFF44336);

  /// Neshan traffic layer — heavy (قرمز تیره).
  static const Color trafficHeavy = Color(0xFFB71C1C);

  static const int trafficSmoothArgb = 0xFFFF9800;
  static const int trafficModerateArgb = 0xFFF44336;
  static const int trafficHeavyArgb = 0xFFB71C1C;

  static const Color routeCasing = Color(0xFFFFFFFF);
  static const int routeCasingArgb = 0xFFFFFFFF;

  /// Slightly transparent route for web-style overlays.
  static const Color routeLineTranslucent = Color(0xCC250ECD);

  static Color colorForTrafficLevel(RouteTrafficLevel level) {
    switch (level) {
      case RouteTrafficLevel.heavy:
        return trafficHeavy;
      case RouteTrafficLevel.moderate:
        return trafficModerate;
      case RouteTrafficLevel.smooth:
        return trafficSmooth;
      case RouteTrafficLevel.clear:
        return routeLine;
    }
  }

  static int argbForTrafficLevel(RouteTrafficLevel level) {
    switch (level) {
      case RouteTrafficLevel.heavy:
        return trafficHeavyArgb;
      case RouteTrafficLevel.moderate:
        return trafficModerateArgb;
      case RouteTrafficLevel.smooth:
        return trafficSmoothArgb;
      case RouteTrafficLevel.clear:
        return routeLineArgb;
    }
  }

  static double overviewLineWidth = 9;
  static double navigationLineWidth = 12;
  static double traveledLineWidth = 7;
}
