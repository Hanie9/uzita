import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/models/driver_trip_phase.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/driver_location_reporter.dart';
import 'package:uzita/services/driver_routing_service.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/driver_location_tracker.dart';
import 'package:uzita/utils/neshan_degraded_route.dart';
import 'package:uzita/utils/neshan_map_preferences.dart';
import 'package:uzita/utils/route_map_geometry.dart';
import 'package:uzita/utils/route_maneuver.dart';
import 'package:uzita/utils/route_progress.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/widgets/driver_map_controller.dart';
import 'package:uzita/widgets/driver_navigation_map.dart';
import 'package:uzita/widgets/neshan_return_to_route_button.dart';

class DriverRouteScreen extends StatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final NeshanLatLng origin;
  final NeshanLatLng destination;

  /// Cargo assignment id (واگذاری بار) — used to report live driver location.
  final int? assignmentId;

  /// Cargo route: pickup (mabda) → delivery (maghsad).
  final NeshanRoute deliveryRoute;

  const DriverRouteScreen({
    super.key,
    required this.originAddress,
    required this.destinationAddress,
    required this.origin,
    required this.destination,
    required NeshanRoute route,
    this.assignmentId,
  }) : deliveryRoute = route;

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen>
    with WidgetsBindingObserver {
  static const _routingService = DriverRoutingService();

  final DriverLocationTracker _locationTracker = DriverLocationTracker();
  final DriverLocationReporter _locationReporter = DriverLocationReporter();
  final ScrollController _stepsScrollController = ScrollController();
  final List<GlobalKey> _stepKeys = [];

  LatLng? _driverPosition;
  double? _driverHeading;
  DriverLocationStatus? _locationStatus;
  int _activeStepIndex = 0;
  bool _navigationActive = false;
  final ValueNotifier<bool> _mapDarkMode = ValueNotifier(false);
  bool _mapCameraDetached = false;
  final DriverMapController _mapController = DriverMapController();
  DriverTripPhase _phase = DriverTripPhase.toPickup;
  NeshanRoute? _pickupRoute;
  bool _pickupRouteLoading = false;

  /// Recomputed delivery route (driver → destination) after the driver goes
  /// off-route during the delivery leg. Null = use the original delivery route.
  NeshanRoute? _deliveryReroute;
  RouteMapGeometry? _deliveryRerouteGeometry;

  /// Off-route detection state for automatic re-routing.
  bool _rerouting = false;
  int _offRouteHits = 0;
  DateTime? _lastRerouteAt;
  static const double _offRouteThresholdMeters = 55;

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
          fullPolyline: driver != null ? [driver, _originLatLng] : const [],
          segments: const [],
        );
      }
      return RouteMapGeometry.fromRoute(
        route,
        origin: driver,
        destination: _originLatLng,
      );
    }
    return _deliveryRerouteGeometry ?? _deliveryGeometry;
  }

  NeshanRoute get _activeRoute {
    if (_phase == DriverTripPhase.toDelivery) {
      return _deliveryReroute ?? widget.deliveryRoute;
    }
    final pickup = _effectivePickupRoute;
    if (pickup != null) return pickup;
    final driver = _driverPosition;
    if (driver != null) {
      return buildDegradedDirectRoute(
        origin: NeshanLatLng(
          latitude: driver.latitude,
          longitude: driver.longitude,
        ),
        destination: widget.origin,
      );
    }
    return buildDegradedDirectRoute(
      origin: widget.origin,
      destination: widget.origin,
    );
  }

  /// Map polyline start (driver GPS during pickup leg).
  LatLng get _mapDisplayOrigin {
    if (_phase == DriverTripPhase.toPickup) {
      if (_driverPosition != null) return _driverPosition!;
      if (_routeCoordinates.length >= 2) return _routeCoordinates.first;
    }
    return _originLatLng;
  }

  /// Map polyline end (mabda during pickup, maghsad during delivery).
  LatLng get _mapDisplayDestination {
    if (_phase == DriverTripPhase.toPickup) return _originLatLng;
    return _destinationLatLng;
  }

  bool get _isPickupLeg => _phase == DriverTripPhase.toPickup;

  NeshanRouteLeg? get _leg => _activeRoute.primaryLeg;

  List<NeshanRouteStep> get _steps => _leg?.steps ?? const [];

  List<LatLng> get _routeCoordinates => _activeGeometry.fullPolyline;

  List<RouteMapSegment> get _routeSegments => _activeGeometry.segments;

  double get _totalDistanceMeters =>
      _leg?.distanceMeters ?? polylineLengthMeters(_routeCoordinates);

  double get _totalDurationSeconds => _leg?.durationSeconds ?? 0;

  bool get _isTracking => _locationStatus == DriverLocationStatus.tracking;

  bool get _isAwaitingGpsLocation => !_isTracking || _driverPosition == null;

  bool get _canConfirmCargoPickup =>
      _phase == DriverTripPhase.toPickup &&
      (_navigationActive || _isNearPickup);

  bool get _isNearPickup {
    final driver = _driverPosition;
    if (driver == null) return false;
    return distanceMeters(driver, _originLatLng) <= 120;
  }

  NeshanRouteStep? get _activeStep => _steps.isEmpty
      ? null
      : _steps[_activeStepIndex.clamp(0, _steps.length - 1)];

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
    WidgetsBinding.instance.addObserver(this);
    _resetStepKeys();
    _loadSavedMapTheme();
    _startLocationTracking();
    if (widget.assignmentId != null) {
      _locationReporter.start(widget.assignmentId!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The driver may have just enabled location services / granted permission
    // from the system settings screen. Re-attempt tracking when we come back so
    // the driver position (and the route to the pickup) finally appears.
    if (state == AppLifecycleState.resumed &&
        (!_isTracking || _driverPosition == null)) {
      _startLocationTracking();
    }
  }

  Future<void> _loadSavedMapTheme() async {
    final dark = await NeshanMapPreferences.isDarkModeEnabled();
    if (!mounted) return;
    _mapDarkMode.value = dark;
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

  Future<void> _loadPickupRoute(LatLng driver, {bool force = false}) async {
    while (_pickupRouteLoading && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!force && _pickupRoute != null) return;

    _pickupRouteLoading = true;
    if (force) {
      _pickupRoute = null;
    }

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
        if (_navigationActive && _driverPosition != null) {
          _activeStepIndex = findActiveStepIndex(
            _steps,
            _driverPosition!,
            previousIndex: _activeStepIndex,
          );
        }
      });
      if (!_navigationActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_navigationActive) {
            unawaited(_mapController.refitOverview());
          }
        });
      }
    } on NeshanApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pickupRoute = buildDegradedDirectRoute(
          origin: driverPoint,
          destination: widget.origin,
        );
        _syncStepKeys();
      });
      if (!_navigationActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_navigationActive) {
            unawaited(_mapController.refitOverview());
          }
        });
      }
      if (kDebugMode) {
        debugPrint('Pickup route fallback: $e');
      }
    } finally {
      _pickupRouteLoading = false;
    }
  }

  bool _isDriverPlausibleForTrip(LatLng driver) {
    if (_phase == DriverTripPhase.toPickup) {
      return distanceMeters(driver, _originLatLng) <= 120000;
    }
    final toOrigin = distanceMeters(driver, _originLatLng);
    final toDestination = distanceMeters(driver, _destinationLatLng);
    return toOrigin <= 200000 || toDestination <= 200000;
  }

  bool _shouldReloadPickupRoute(LatLng position) {
    if (_pickupRoute == null) return true;
    final first = _pickupRoute!.primaryLeg?.steps.firstOrNull?.startLocation;
    if (first == null) return true;
    return distanceMeters(position, LatLng(first.latitude, first.longitude)) >
        1500;
  }

  void _confirmCargoPickedUp() {
    setState(() {
      _phase = DriverTripPhase.toDelivery;
      _deliveryReroute = null;
      _deliveryRerouteGeometry = null;
      _offRouteHits = 0;
      _lastRerouteAt = null;
      _resetStepKeys();
      _mapCameraDetached = false;
    });
    _scrollToActiveStep();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapDarkMode.dispose();
    _locationTracker.dispose();
    _locationReporter.stop();
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

    final driver = _driverPosition;
    if (driver == null) return;

    final localizations = AppLocalizations.of(context)!;
    if (!_isDriverPlausibleForTrip(driver)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.driver_route_gps_too_far)),
      );
      return;
    }

    if (_phase == DriverTripPhase.toPickup) {
      if (_pickupRoute == null) {
        await _loadPickupRoute(driver);
      } else if (_shouldReloadPickupRoute(driver)) {
        await _loadPickupRoute(driver, force: true);
      }
      if (!mounted) return;
    }

    final newStep = findActiveStepIndex(
      _steps,
      driver,
      previousIndex: _activeStepIndex,
    );

    setState(() {
      _navigationActive = true;
      _mapCameraDetached = false;
      _activeStepIndex = newStep;
    });
    _syncStepKeys();

    // Wait one frame so followDriver propagates before moving the camera.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _mapController.resumeNavigation(
      position: driver,
      heading: _driverHeading,
    );

    // Ensure navigation camera wins over any pending overview refit.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || !_navigationActive) return;
    await _mapController.resumeNavigation(
      position: driver,
      heading: _driverHeading,
    );

    // Some Neshan platform-view camera commands can arrive out of order during
    // the overview->navigation transition. Apply one last follow move after the
    // native view has had time to redraw the route overlay.
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted || !_navigationActive || _mapCameraDetached) return;
    await _mapController.resumeNavigation(
      position: _driverPosition ?? driver,
      heading: _driverHeading,
    );

    if (!mounted) return;
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

    _locationReporter.updatePosition(position.latitude, position.longitude);

    setState(() {
      _driverPosition = position;
      _driverHeading = resolvedHeading;
      _locationStatus = DriverLocationStatus.tracking;
      _activeStepIndex = newActiveStep;
    });

    if (_phase == DriverTripPhase.toPickup) {
      if (_shouldReloadPickupRoute(position)) {
        _loadPickupRoute(position, force: _pickupRoute != null);
      } else if (_pickupRoute == null) {
        _loadPickupRoute(position);
      }
    }
    _syncStepKeys();

    if (_navigationActive && _isTracking && !_mapCameraDetached) {
      unawaited(
        _mapController.tickNavigation(
          position: position,
          heading: resolvedHeading,
        ),
      );
    }

    if (_navigationActive && _isTracking) {
      _maybeRerouteOffRoute(position);
    }

    if (stepChanged) {
      _scrollToActiveStep();
    }
  }

  /// Detects when the driver has left the planned route and triggers a new
  /// route (and ETA) from the current position. Requires several consecutive
  /// off-route fixes and a cooldown so GPS noise / brief detours don't spam it.
  void _maybeRerouteOffRoute(LatLng driver) {
    if (_rerouting) return;
    final route = _routeCoordinates;
    if (route.length < 2) return;

    final offBy = distanceToPolylineMeters(route, driver);
    if (offBy <= _offRouteThresholdMeters) {
      _offRouteHits = 0;
      return;
    }

    _offRouteHits++;
    if (_offRouteHits < 3) return;

    final now = DateTime.now();
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < const Duration(seconds: 15)) {
      return;
    }
    _offRouteHits = 0;
    _lastRerouteAt = now;
    unawaited(_rerouteFromDriver(driver));
  }

  Future<void> _rerouteFromDriver(LatLng driver) async {
    if (_rerouting) return;
    _rerouting = true;
    try {
      if (_phase == DriverTripPhase.toPickup) {
        await _loadPickupRoute(driver, force: true);
      } else {
        final route = await _routingService.getRoute(
          origin: NeshanLatLng(
            latitude: driver.latitude,
            longitude: driver.longitude,
          ),
          destination: widget.destination,
        );
        if (!mounted) return;
        setState(() {
          _deliveryReroute = route;
          _deliveryRerouteGeometry = RouteMapGeometry.fromRoute(
            route,
            origin: driver,
            destination: _destinationLatLng,
          );
          _activeStepIndex = 0;
          _syncStepKeys();
        });
      }

      if (mounted && _navigationActive && !_mapCameraDetached) {
        await _mapController.resumeNavigation(
          position: _driverPosition ?? driver,
          heading: _driverHeading,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Reroute failed: $e');
      }
    } finally {
      _rerouting = false;
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

  String _searchingLocationText(AppLocalizations localizations) =>
      localizations.driver_route_searching_location;

  String _routeSummaryText() {
    if (_isAwaitingGpsLocation) return '';
    return _leg?.summary ?? '';
  }

  int _remainingMetersValue() {
    if (_isAwaitingGpsLocation) return 0;

    final remainingMeters = polylineLengthMeters(
      _routeCoordinates,
      startIndex: _traveledPolylineIndex,
    );

    if (_phase == DriverTripPhase.toPickup && _driverPosition != null) {
      final legMeters = _leg?.distanceMeters;
      final directToOrigin = distanceMeters(_driverPosition!, _originLatLng);
      if (remainingMeters > 100000 ||
          (legMeters != null && remainingMeters > legMeters * 4)) {
        return directToOrigin.round();
      }
    }

    return remainingMeters.round();
  }

  String _remainingDistanceText(AppLocalizations localizations) {
    if (_isAwaitingGpsLocation) {
      return _searchingLocationText(localizations);
    }

    final remainingMeters = _remainingMetersValue();

    if (remainingMeters >= 1000) {
      final km = (remainingMeters / 1000).toStringAsFixed(1);
      return _isPersian(localizations) ? '$km کیلومتر' : '$km km';
    }
    final meters = remainingMeters.round();
    return _isPersian(localizations) ? '$meters متر' : '$meters m';
  }

  String _remainingDurationText(AppLocalizations localizations) {
    if (_isAwaitingGpsLocation) {
      return _searchingLocationText(localizations);
    }

    return formatDurationSeconds(
      _remainingDurationSecondsValue(),
      persian: _isPersian(localizations),
    );
  }

  String _arrivalTimeText(AppLocalizations localizations) {
    if (_isAwaitingGpsLocation) {
      return _searchingLocationText(localizations);
    }

    final seconds = _remainingDurationSecondsValue();
    final arrival = DateTime.now().add(Duration(seconds: seconds));
    return formatClockTime(arrival);
  }

  int _remainingDurationSecondsValue() {
    if (_driverPosition == null || !_isTracking) {
      return _totalDurationSeconds.round();
    }

    final remainingMeters = _remainingMetersValue().toDouble();
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

  void _toggleMapTheme() {
    final next = !_mapDarkMode.value;
    _mapDarkMode.value = next;
    NeshanMapPreferences.setDarkModeEnabled(next);
  }

  void _onMapCameraDetached(bool detached) {
    if (!mounted) return;
    if (detached && !_navigationActive) return;
    if (_mapCameraDetached == detached) return;
    setState(() => _mapCameraDetached = detached);
  }

  Future<void> _returnToRoute() async {
    if (_navigationActive) {
      final position = _driverPosition;
      if (position == null) return;
      setState(() => _mapCameraDetached = false);
      await _mapController.resumeNavigation(
        position: position,
        heading: _driverHeading,
      );
    } else {
      await _mapController.refitOverview();
    }
  }

  Widget _phaseHeaderWithTheme(
    AppLocalizations localizations, {
    double horizontalPadding = 12,
    double topPadding = 8,
    double bottomPadding = 8,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _mapDarkMode,
            builder: (context, isDark, _) => _MapThemeToggleButton(
              isDark: isDark,
              onPressed: _toggleMapTheme,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TripPhaseBanner(
              phase: _phase,
              pickupLabel: localizations.driver_route_phase_pickup,
              deliveryLabel: localizations.driver_route_phase_delivery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _returnToRouteButton(
    AppLocalizations localizations, {
    double bottom = 16,
  }) {
    if (!_navigationActive || !_mapCameraDetached) {
      return const SizedBox.shrink();
    }
    return NeshanReturnToRouteButton(
      label: localizations.driver_route_return_to_route,
      onPressed: _returnToRoute,
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncStepKeys();
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final persian = _isPersian(localizations);

    return Scaffold(
      backgroundColor: _navigationActive
          ? Colors.transparent
          : Theme.of(context).scaffoldBackgroundColor,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(
                  localizations.driver_route_cargo_picked_up,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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
        child: _buildRouteBody(localizations, persian, ui),
      ),
    );
  }

  Widget _buildDriverMap(AppLocalizations localizations) {
    return ValueListenableBuilder<bool>(
      valueListenable: _mapDarkMode,
      builder: (context, isDark, _) => DriverNavigationMap(
        key: const ValueKey('driver_route_map'),
        routeCoordinates: _routeCoordinates,
        routeSegments: _routeSegments,
        origin: _mapDisplayOrigin,
        destination: _mapDisplayDestination,
        driverPosition: _isTracking ? _driverPosition : null,
        driverHeading: _isTracking ? _driverHeading : null,
        followDriver: _navigationActive && _isTracking,
        navigationMode: _navigationActive,
        isDark: isDark,
        overviewMode: !_navigationActive,
        pickupLeg: _isPickupLeg,
        traveledFromIndex: _traveledPolylineIndex,
        returnToRouteLabel: localizations.driver_route_return_to_route,
        controller: _mapController,
        onCameraDetached: _onMapCameraDetached,
      ),
    );
  }

  Widget _buildRouteBody(
    AppLocalizations localizations,
    bool persian,
    UiScale ui,
  ) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildDriverMap(localizations),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _phaseHeaderWithTheme(
                    localizations,
                    horizontalPadding: _navigationActive
                        ? 12
                        : ui.scale(base: 12, min: 10, max: 16),
                    topPadding: _navigationActive
                        ? 8
                        : ui.scale(base: 8, min: 6, max: 10),
                  ),
                  if (_navigationActive && _activeStep != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _NavigationGuidanceCard(
                        step: _activeStep!,
                        nextStep: _nextStep,
                        distanceMeters: _distanceToActiveStepMeters(),
                        persian: persian,
                        thenLabel: localizations.driver_route_then,
                      ),
                    ),
                ],
              ),
              _returnToRouteButton(localizations, bottom: 20),
            ],
          ),
        ),
        if (_navigationActive)
          _NavigationBottomBar(
            remainingDistance: _remainingDistanceText(localizations),
            remainingDuration: _remainingDurationText(localizations),
            arrivalTime: _arrivalTimeText(localizations),
            distanceLabel: localizations.driver_route_remaining,
            durationLabel: localizations.driver_route_duration,
            arrivalLabel: localizations.driver_route_arrival,
            awaitingGpsLocation: _isAwaitingGpsLocation,
            searchingLocationText: _searchingLocationText(localizations),
          )
        else
          _OverviewBottomPanel(
            originLabel: localizations.driver_mabda,
            originValue: widget.originAddress,
            destinationLabel: localizations.driver_maghsad,
            destinationValue: widget.destinationAddress,
            distanceText: _remainingDistanceText(localizations),
            durationText: _remainingDurationText(localizations),
            arrivalText: _arrivalTimeText(localizations),
            summary: _routeSummaryText(),
            distanceLabel: localizations.driver_route_distance,
            durationLabel: localizations.driver_route_duration,
            arrivalLabel: localizations.driver_route_arrival,
            awaitingGpsLocation: _isAwaitingGpsLocation,
            searchingLocationText: _searchingLocationText(localizations),
            hint: _phase == DriverTripPhase.toPickup
                ? localizations.driver_route_pickup_hint
                : localizations.driver_route_delivery_hint,
          ),
      ],
    );
  }
}

class _MapThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onPressed;

  const _MapThemeToggleButton({required this.isDark, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF334155),
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _OverviewBottomPanel extends StatelessWidget {
  final String originLabel;
  final String originValue;
  final String destinationLabel;
  final String destinationValue;
  final String distanceText;
  final String durationText;
  final String arrivalText;
  final String summary;
  final String distanceLabel;
  final String durationLabel;
  final String arrivalLabel;
  final String hint;
  final bool awaitingGpsLocation;
  final String searchingLocationText;

  const _OverviewBottomPanel({
    required this.originLabel,
    required this.originValue,
    required this.destinationLabel,
    required this.destinationValue,
    required this.distanceText,
    required this.durationText,
    required this.arrivalText,
    required this.summary,
    required this.distanceLabel,
    required this.durationLabel,
    required this.arrivalLabel,
    required this.hint,
    this.awaitingGpsLocation = false,
    this.searchingLocationText = '',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (summary.isNotEmpty && !awaitingGpsLocation)
                Text(
                  summary,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.lapisLazuli,
                  ),
                ),
              if (summary.isNotEmpty && !awaitingGpsLocation)
                const SizedBox(height: 10),
              if (awaitingGpsLocation)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.gps_not_fixed,
                        color: AppColors.lapisLazuli,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          searchingLocationText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _OverviewChip(
                        icon: Icons.straighten,
                        label: distanceLabel,
                        value: distanceText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OverviewChip(
                        icon: Icons.schedule,
                        label: durationLabel,
                        value: durationText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OverviewChip(
                        icon: Icons.flag,
                        label: arrivalLabel,
                        value: arrivalText,
                        highlight: true,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              _AddressRow(
                icon: Icons.trip_origin,
                label: originLabel,
                value: originValue,
                color: AppColors.iranianGray,
              ),
              const SizedBox(height: 8),
              _AddressRow(
                icon: Icons.location_on,
                label: destinationLabel,
                value: destinationValue,
                color: AppColors.lapisLazuli,
              ),
              const SizedBox(height: 10),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.iranianGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _OverviewChip({
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
            ? AppColors.lapisLazuli.withValues(alpha: 0.1)
            : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? AppColors.lapisLazuli : AppColors.iranianGray,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: highlight ? AppColors.lapisLazuli : AppColors.iranianGray,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.lapisLazuli : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AddressRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppColors.iranianGray),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(maneuverIcon(step), color: Colors.white, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    maneuverDistancePrefix(distanceMeters, persian: persian),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.name.isNotEmpty ? step.name : step.instruction,
                    style: const TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (nextStep != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$thenLabel: ${nextStep!.instruction}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
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

class _NavigationBottomBar extends StatelessWidget {
  final String remainingDistance;
  final String remainingDuration;
  final String arrivalTime;
  final String distanceLabel;
  final String durationLabel;
  final String arrivalLabel;
  final bool awaitingGpsLocation;
  final String searchingLocationText;

  const _NavigationBottomBar({
    required this.remainingDistance,
    required this.remainingDuration,
    required this.arrivalTime,
    required this.distanceLabel,
    required this.durationLabel,
    required this.arrivalLabel,
    this.awaitingGpsLocation = false,
    this.searchingLocationText = '',
  });

  @override
  Widget build(BuildContext context) {
    final barColor = Theme.of(context).cardTheme.color ?? Colors.white;

    return ColoredBox(
      color: barColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: awaitingGpsLocation
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.gps_not_fixed,
                      color: AppColors.lapisLazuli,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        searchingLocationText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _BottomMetric(
                        icon: Icons.straighten,
                        label: distanceLabel,
                        value: remainingDistance,
                      ),
                    ),
                    _barDivider(),
                    Expanded(
                      child: _BottomMetric(
                        icon: Icons.schedule,
                        label: durationLabel,
                        value: remainingDuration,
                      ),
                    ),
                    _barDivider(),
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
      ),
    );
  }

  Widget _barDivider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: Colors.grey.withValues(alpha: 0.3),
  );
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: highlight ? const Color(0xFF0077B6) : AppColors.iranianGray,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.iranianGray),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '---' : value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight
                ? const Color(0xFF0077B6)
                : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
