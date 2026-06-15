import 'package:latlong2/latlong.dart';

/// Bridges [DriverNavigationMap] actions to the parent screen overlays.
class DriverMapController {
  Future<void> Function()? _refitOverview;
  Future<void> Function(LatLng position, double? heading)? _resumeNavigation;
  Future<void> Function(LatLng position, double? heading)? _tickNavigation;

  void bind({
    required Future<void> Function() refitOverview,
    required Future<void> Function(LatLng position, double? heading)
        resumeNavigation,
    Future<void> Function(LatLng position, double? heading)? tickNavigation,
  }) {
    _refitOverview = refitOverview;
    _resumeNavigation = resumeNavigation;
    _tickNavigation = tickNavigation;
  }

  void unbind() {
    _refitOverview = null;
    _resumeNavigation = null;
    _tickNavigation = null;
  }

  Future<void> refitOverview() async {
    final action = _refitOverview;
    if (action != null) await action();
  }

  Future<void> resumeNavigation({
    required LatLng position,
    double? heading,
  }) async {
    final action = _resumeNavigation;
    if (action != null) await action(position, heading);
  }

  Future<void> tickNavigation({
    required LatLng position,
    double? heading,
  }) async {
    final action = _tickNavigation ?? _resumeNavigation;
    if (action != null) await action(position, heading);
  }
}
