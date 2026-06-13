import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/models/driver_trip_phase.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/driver_routing_service.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/driver_location_tracker.dart';
import 'package:uzita/utils/neshan_degraded_route.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_maneuver.dart';
import 'package:uzita/utils/route_progress.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/widgets/driver_navigation_map.dart';

class DriverRouteScreen extends StatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final NeshanLatLng origin;
  final NeshanLatLng destination;
  /// Cargo route: pickup (mabda) → delivery (maghsad).
  final NeshanRoute deliveryRoute;

  const DriverRouteScreen({
    super.key,
    required this.originAddress,
    required this.destinationAddress,
    required this.origin,
    required this.destination,
    required NeshanRoute route,
  }) : deliveryRoute = route;

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  static const _routingService = DriverRoutingService();

  final DriverLocationTracker _locationTracker = DriverLocationTracker();
  final ScrollController _stepsScrollController = ScrollController();
  final List<GlobalKey> _stepKeys = [];

  LatLng? _driverPosition;
  double? _driverHeading;
  DriverLocationStatus? _locationStatus;
  int _activeStepIndex = 0;
  bool _navigationActive = false;
  DriverTripPhase _phase = DriverTripPhase.toPickup;
  NeshanRoute? _pickupRoute;
  bool _pickupRouteLoading = false;

  LatLng get _originLatLng =>
      LatLng(widget.origin.latitude, widget.origin.longitude);

  LatLng get _destinationLatLng =>
      LatLng(widget.destination.latitude, widget.destination.longitude);

  late final RouteMapGeometry _deliveryGeometry = RouteMapGeometry.fromRoute(
    widget.deliveryRoute,
    origin: _originLatLng,
    destination: _destinationLatLng,
  );

  NeshanRoute? get _effectivePickupRoute {
    if (_pickupRoute != null) return _pickupRoute;
    final driver = _driverPosition;
    if (driver == null) return null;
    return buildDegradedDirectRoute(
      origin: NeshanLatLng(
        latitude: driver.latitude,
        longitude: driver.longitude,
      ),
      destination: widget.origin,
    );
  }

  RouteMapGeometry get _activeGeometry {
    if (_phase == DriverTripPhase.toPickup) {
      final route = _effectivePickupRoute;
      final driver = _driverPosition;
      if (route == null || driver == null) {
        return RouteMapGeometry(
          fullPolyline: driver != null
              ? [driver, _originLatLng]
              : [_originLatLng, _destinationLatLng],
          segments: const [],
        );
      }
      return RouteMapGeometry.fromRoute(
        route,
        origin: driver,
        destination: _originLatLng,
      );
    }
    return _deliveryGeometry;
  }

  NeshanRoute get _activeRoute =>
      _phase == DriverTripPhase.toPickup
      ? (_effectivePickupRoute ?? widget.deliveryRoute)
      : widget.deliveryRoute;

  NeshanRouteLeg? get _leg => _activeRoute.primaryLeg;

  List<NeshanRouteStep> get _steps => _leg?.steps ?? const [];

  List<LatLng> get _routeCoordinates => _activeGeometry.fullPolyline;

  List<RouteMapSegment> get _routeSegments => _activeGeometry.segments;

  double get _totalDistanceMeters =>
      _leg?.distanceMeters ?? polylineLengthMeters(_routeCoordinates);

  double get _totalDurationSeconds => _leg?.durationSeconds ?? 0;

  bool get _isTracking => _locationStatus == DriverLocationStatus.tracking;

  bool get _canConfirmCargoPickup =>
      _phase == DriverTripPhase.toPickup &&
      (_navigationActive || _isNearPickup);

  bool get _isNearPickup {
    final driver = _driverPosition;
    if (driver == null) return false;
    return distanceMeters(driver, _originLatLng) <= 120;
  }

  NeshanRouteStep? get _activeStep =>
      _steps.isEmpty ? null : _steps[_activeStepIndex.clamp(0, _steps.length - 1)];

  NeshanRouteStep? get _nextStep {
    if (_steps.isEmpty || _activeStepIndex >= _steps.length - 1) return null;
    return _steps[_activeStepIndex + 1];
  }

  int get _traveledPolylineIndex {
    if (_driverPosition == null || !_isTracking) return 0;
    return findClosestPolylineIndex(_routeCoordinates, _driverPosition!);
  }

  @override
  void initState() {
    super.initState();
    _resetStepKeys();
    _startLocationTracking();
  }

  void _syncStepKeys() {
    final count = _steps.length;
    if (_stepKeys.length == count) return;
    _stepKeys
      ..clear()
      ..addAll(List.generate(count, (_) => GlobalKey()));
    if (count == 0) {
      _activeStepIndex = 0;
    } else {
      _activeStepIndex = _activeStepIndex.clamp(0, count - 1);
    }
  }

  void _resetStepKeys() {
    _stepKeys
      ..clear()
      ..addAll(List.generate(_steps.length, (_) => GlobalKey()));
    _activeStepIndex = 0;
  }

  Future<void> _loadPickupRoute(LatLng driver) async {
    if (_pickupRoute != null || _pickupRouteLoading) return;
    _pickupRouteLoading = true;

    final driverPoint = NeshanLatLng(
      latitude: driver.latitude,
      longitude: driver.longitude,
    );

    try {
      final route = await _routingService.getRoute(
        origin: driverPoint,
        destination: widget.origin,
      );
      if (!mounted) return;
      setState(() {
        _pickupRoute = route;
        _syncStepKeys();
      });
    } on NeshanApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pickupRoute = buildDegradedDirectRoute(
          origin: driverPoint,
          destination: widget.origin,
        );
        _syncStepKeys();
      });
      if (kDebugMode) {
        debugPrint('Pickup route fallback: $e');
      }
    } finally {
      _pickupRouteLoading = false;
    }
  }

  void _confirmCargoPickedUp() {
    setState(() {
      _phase = DriverTripPhase.toDelivery;
      _resetStepKeys();
    });
    _scrollToActiveStep();
  }

  @override
  void dispose() {
    _locationTracker.dispose();
    _stepsScrollController.dispose();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    final status = await _locationTracker.start(
      onUpdate: _onDriverLocationUpdated,
    );
    if (!mounted) return;

    setState(() => _locationStatus = status);

    if (status == DriverLocationStatus.tracking) {
      final current = await _locationTracker.getCurrentSnapshot();
      if (current != null && mounted) {
        _onDriverLocationUpdated(current);
      }
    }
  }

  Future<void> _requestLocationAgain() async {
    final ready = await _locationTracker.ensureAccess();
    if (!mounted) return;

    if (!ready) {
      setState(() => _locationStatus = _locationTracker.lastStatus);
      return;
    }

    await _startLocationTracking();
  }

  Future<void> _startNavigation() async {
    if (!_isTracking) {
      await _requestLocationAgain();
      if (!mounted || !_isTracking) return;
    }
    setState(() => _navigationActive = true);
    _scrollToActiveStep();
  }

  void _onDriverLocationUpdated(DriverLocationSnapshot update) {
    if (!mounted) return;

    final position = update.position;
    final newActiveStep = findActiveStepIndex(
      _steps,
      position,
      previousIndex: _activeStepIndex,
    );

    final stepChanged = newActiveStep != _activeStepIndex;
    final resolvedHeading = resolveDriverHeading(
      position: position,
      deviceHeading: update.heading,
      speedMps: update.speedMps,
      previousPosition: _driverPosition,
      routePolyline: _routeCoordinates,
    );

    setState(() {
      _driverPosition = position;
      _driverHeading = resolvedHeading;
      _locationStatus = DriverLocationStatus.tracking;
      _activeStepIndex = newActiveStep;
    });

    if (_phase == DriverTripPhase.toPickup) {
      _loadPickupRoute(position);
    }
    _syncStepKeys();

    if (stepChanged) {
      _scrollToActiveStep();
    }
  }

  void _scrollToActiveStep() {
    if (_activeStepIndex < 0 || _activeStepIndex >= _stepKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _stepKeys[_activeStepIndex].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      }
    });
  }

  bool _isPersian(AppLocalizations localizations) =>
      localizations.effectiveLanguageCode != 'en';

  String _remainingDistanceText(AppLocalizations localizations) {
    if (_driverPosition == null || !_isTracking) {
      return _leg?.distanceText ?? '---';
    }

    final remainingMeters = polylineLengthMeters(
      _routeCoordinates,
      startIndex: _traveledPolylineIndex,
    );

    if (remainingMeters >= 1000) {
      final km = (remainingMeters / 1000).toStringAsFixed(1);
      return _isPersian(localizations) ? '$km کیلومتر' : '$km km';
    }
    final meters = remainingMeters.round();
    return _isPersian(localizations) ? '$meters متر' : '$meters m';
  }

  String _remainingDurationText(AppLocalizations localizations) {
    if (_driverPosition == null || !_isTracking) {
      return _leg?.durationText ?? '---';
    }

    return formatDurationSeconds(
      _remainingDurationSecondsValue(),
      persian: _isPersian(localizations),
    );
  }

  String _arrivalTimeText() {
    final seconds = _remainingDurationSecondsValue();
    final arrival = DateTime.now().add(Duration(seconds: seconds));
    return formatClockTime(arrival);
  }

  int _remainingDurationSecondsValue() {
    if (_driverPosition == null || !_isTracking) {
      return _totalDurationSeconds.round();
    }

    final remainingMeters = polylineLengthMeters(
      _routeCoordinates,
      startIndex: _traveledPolylineIndex,
    );
    return estimateRemainingSeconds(
      totalSeconds: _totalDurationSeconds,
      totalMeters: _totalDistanceMeters,
      remainingMeters: remainingMeters,
    ).round();
  }

  double _distanceToActiveStepMeters() {
    final step = _activeStep;
    if (step == null || _driverPosition == null) return 0;
    return distanceToStepMeters(
      driver: _driverPosition!,
      step: step,
      routePolyline: _routeCoordinates,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncStepKeys();
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final persian = _isPersian(localizations);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          localizations.driver_navigate,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          if (_canConfirmCargoPickup)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                onPressed: _confirmCargoPickedUp,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(
                  localizations.driver_route_cargo_picked_up,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          if (!_navigationActive)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                onPressed: _startNavigation,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lapisLazuli,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: Text(
                  _phase == DriverTripPhase.toPickup
                      ? localizations.driver_route_start_to_pickup
                      : localizations.driver_route_start_navigation,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Directionality(
        textDirection: persian ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Expanded(
              flex: _navigationActive ? 5 : 4,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DriverNavigationMap(
                      routeCoordinates: _routeCoordinates,
                      routeSegments: _routeSegments,
                      origin: _originLatLng,
                      destination: _destinationLatLng,
                      driverPosition: _isTracking ? _driverPosition : null,
                      driverHeading: _isTracking ? _driverHeading : null,
                      followDriver: _navigationActive && _isTracking,
                      isDark: isDark,
                      traveledFromIndex: _navigationActive
                          ? _traveledPolylineIndex
                          : null,
                    ),
                  ),
                  if (_navigationActive && _activeStep != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TripPhaseBanner(
                            phase: _phase,
                            pickupLabel: localizations.driver_route_phase_pickup,
                            deliveryLabel:
                                localizations.driver_route_phase_delivery,
                          ),
                          _NavigationGuidanceCard(
                            step: _activeStep!,
                            nextStep: _nextStep,
                            distanceMeters: _distanceToActiveStepMeters(),
                            persian: persian,
                            thenLabel: localizations.driver_route_then,
                          ),
                        ],
                      ),
                    ),
                  if (!_navigationActive)
                    Positioned(
                      top: ui.scale(base: 12, min: 8, max: 16),
                      left: ui.scale(base: 12, min: 8, max: 16),
                      right: ui.scale(base: 12, min: 8, max: 16),
                      child: _TripPhaseBanner(
                        phase: _phase,
                        pickupLabel: localizations.driver_route_phase_pickup,
                        deliveryLabel: localizations.driver_route_phase_delivery,
                      ),
                    ),
                  if (!_isTracking) _buildLocationBanner(localizations, ui),
                  if (!_navigationActive)
                    Positioned(
                      left: ui.scale(base: 16, min: 12, max: 20),
                      right: ui.scale(base: 16, min: 12, max: 20),
                      bottom: ui.scale(base: 14, min: 10, max: 18),
                      child: _NavigationHintBanner(
                        hint: _phase == DriverTripPhase.toPickup
                            ? localizations.driver_route_pickup_hint
                            : localizations.driver_route_delivery_hint,
                      ),
                    ),
                ],
              ),
            ),
            if (_navigationActive)
              _NavigationBottomBar(
                remainingDistance: _remainingDistanceText(localizations),
                remainingDuration: _remainingDurationText(localizations),
                arrivalTime: _arrivalTimeText(),
                distanceLabel: localizations.driver_route_remaining,
                durationLabel: localizations.driver_route_duration,
                arrivalLabel: localizations.driver_route_arrival,
              )
            else if (_leg != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 16, min: 12, max: 20),
                  ui.scale(base: 10, min: 8, max: 12),
                  ui.scale(base: 16, min: 12, max: 20),
                  ui.scale(base: 6, min: 4, max: 8),
                ),
                child: _RouteSummaryCard(
                  summary: _leg!.summary,
                  distanceText: _remainingDistanceText(localizations),
                  durationText: _remainingDurationText(localizations),
                  arrivalText: _arrivalTimeText(),
                  distanceLabel: localizations.driver_route_distance,
                  durationLabel: localizations.driver_route_duration,
                  arrivalLabel: localizations.driver_route_arrival,
                ),
              ),
            Expanded(
              flex: _navigationActive ? 2 : 3,
              child: ListView(
                controller: _stepsScrollController,
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 16, min: 12, max: 20),
                  ui.scale(base: 8, min: 6, max: 10),
                  ui.scale(base: 16, min: 12, max: 20),
                  ui.scale(base: 16, min: 12, max: 20) +
                      MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _AddressCard(
                    icon: Icons.trip_origin,
                    title: localizations.driver_mabda,
                    value: widget.originAddress,
                    iconColor: AppColors.iranianGray,
                  ),
                  SizedBox(height: ui.scale(base: 10, min: 8, max: 12)),
                  _AddressCard(
                    icon: Icons.location_on,
                    title: localizations.driver_maghsad,
                    value: widget.destinationAddress,
                    iconColor: AppColors.lapisLazuli,
                  ),
                  if (_steps.isNotEmpty) ...[
                    SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                    Text(
                      localizations.driver_route_steps,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: ui.scale(base: 10, min: 8, max: 12)),
                    ...List.generate(_steps.length, (index) {
                      final step = _steps[index];
                      final isActive =
                          _navigationActive &&
                          _isTracking &&
                          index == _activeStepIndex;
                      final isCompleted =
                          _navigationActive &&
                          _isTracking &&
                          index < _activeStepIndex;
                      return _StepTile(
                        key: _stepKeys[index],
                        index: index + 1,
                        step: step,
                        isLast: index == _steps.length - 1,
                        isActive: isActive,
                        isCompleted: isCompleted,
                        completedLabel: localizations.driver_route_step_completed,
                        currentLabel: localizations.driver_route_step_current,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBanner(AppLocalizations localizations, UiScale ui) {
    final message = switch (_locationStatus) {
      DriverLocationStatus.permissionDenied =>
        localizations.driver_route_location_denied,
      DriverLocationStatus.serviceDisabled =>
        localizations.driver_route_location_disabled,
      _ => localizations.driver_route_location_off,
    };

    return Positioned(
      left: ui.scale(base: 12, min: 10, max: 16),
      right: ui.scale(base: 12, min: 10, max: 16),
      bottom: ui.scale(base: 90, min: 80, max: 100),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.location_disabled, color: AppColors.iranianGray),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: _requestLocationAgain,
                child: Text(localizations.driver_route_enable_location),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationGuidanceCard extends StatelessWidget {
  final NeshanRouteStep step;
  final NeshanRouteStep? nextStep;
  final double distanceMeters;
  final bool persian;
  final String thenLabel;

  const _NavigationGuidanceCard({
    required this.step,
    required this.nextStep,
    required this.distanceMeters,
    required this.persian,
    required this.thenLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      color: AppColors.lapisLazuli,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                maneuverIcon(step),
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maneuverDistancePrefix(distanceMeters, persian: persian),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (step.name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (nextStep != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$thenLabel: ${nextStep!.instruction}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripPhaseBanner extends StatelessWidget {
  final DriverTripPhase phase;
  final String pickupLabel;
  final String deliveryLabel;

  const _TripPhaseBanner({
    required this.phase,
    required this.pickupLabel,
    required this.deliveryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isPickup = phase == DriverTripPhase.toPickup;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: isPickup
          ? const Color(0xFF16A34A).withValues(alpha: 0.92)
          : const Color(0xFFEA580C).withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              isPickup ? Icons.local_shipping_outlined : Icons.flag_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPickup ? pickupLabel : deliveryLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationHintBanner extends StatelessWidget {
  final String hint;

  const _NavigationHintBanner({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.lapisLazuli),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.iranianGray,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBottomBar extends StatelessWidget {
  final String remainingDistance;
  final String remainingDuration;
  final String arrivalTime;
  final String distanceLabel;
  final String durationLabel;
  final String arrivalLabel;

  const _NavigationBottomBar({
    required this.remainingDistance,
    required this.remainingDuration,
    required this.arrivalTime,
    required this.distanceLabel,
    required this.durationLabel,
    required this.arrivalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _BottomMetric(
                icon: Icons.straighten,
                label: distanceLabel,
                value: remainingDistance,
              ),
            ),
            Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
            Expanded(
              child: _BottomMetric(
                icon: Icons.schedule,
                label: durationLabel,
                value: remainingDuration,
              ),
            ),
            Container(width: 1, height: 32, color: Colors.grey.withValues(alpha: 0.3)),
            Expanded(
              child: _BottomMetric(
                icon: Icons.flag,
                label: arrivalLabel,
                value: arrivalTime,
                highlight: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _BottomMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: highlight ? AppColors.lapisLazuli : AppColors.iranianGray,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.iranianGray),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.lapisLazuli : null,
          ),
        ),
      ],
    );
  }
}

class _AddressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  const _AddressCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.iranianGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  final String summary;
  final String distanceText;
  final String durationText;
  final String arrivalText;
  final String distanceLabel;
  final String durationLabel;
  final String arrivalLabel;

  const _RouteSummaryCard({
    required this.summary,
    required this.distanceText,
    required this.durationText,
    required this.arrivalText,
    required this.distanceLabel,
    required this.durationLabel,
    required this.arrivalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lapisLazuli.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lapisLazuli.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.route, size: 18, color: AppColors.lapisLazuli),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lapisLazuli,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricChip(
                  icon: Icons.straighten,
                  label: distanceLabel,
                  value: distanceText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricChip(
                  icon: Icons.schedule,
                  label: durationLabel,
                  value: durationText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricChip(
                  icon: Icons.flag,
                  label: arrivalLabel,
                  value: arrivalText,
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.lapisLazuli.withValues(alpha: 0.12)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: highlight ? AppColors.lapisLazuli : AppColors.iranianGray,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: highlight
                        ? AppColors.lapisLazuli
                        : AppColors.iranianGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.lapisLazuli : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final NeshanRouteStep step;
  final bool isLast;
  final bool isActive;
  final bool isCompleted;
  final String completedLabel;
  final String currentLabel;

  const _StepTile({
    super.key,
    required this.index,
    required this.step,
    required this.isLast,
    required this.isActive,
    required this.isCompleted,
    required this.completedLabel,
    required this.currentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppColors.lapisLazuli
        : Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : AppColors.lapisLazuli.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.lapisLazuli
                      : isCompleted
                      ? AppColors.iranianGray.withValues(alpha: 0.2)
                      : AppColors.lapisLazuli.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: AppColors.iranianGray)
                    : Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : AppColors.lapisLazuli,
                        ),
                      ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 20,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isCompleted
                      ? AppColors.iranianGray.withValues(alpha: 0.35)
                      : AppColors.lapisLazuli.withValues(alpha: 0.15),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.lapisLazuli.withValues(alpha: 0.08)
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isActive || isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        isActive ? currentLabel : completedLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.lapisLazuli
                              : AppColors.iranianGray,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        maneuverIcon(step),
                        size: 18,
                        color: isActive
                            ? AppColors.lapisLazuli
                            : AppColors.iranianGray,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.instruction,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isCompleted
                                ? AppColors.iranianGray
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (step.name.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        step.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.iranianGray,
                        ),
                      ),
                    ),
                  ],
                  if (step.distanceText.isNotEmpty ||
                      step.durationText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        [
                          if (step.distanceText.isNotEmpty) step.distanceText,
                          if (step.durationText.isNotEmpty) step.durationText,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.iranianGray,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
