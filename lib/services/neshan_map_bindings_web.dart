import 'dart:async';
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

/// Web: JS bridge to [web/neshan_map_bridge.js] + Neshan Mapbox GL SDK.
class NeshanMapBindings {
  NeshanMapBindings._();

  static bool _eventsHooked = false;
  static final StreamController<dynamic> _eventController =
      StreamController<dynamic>.broadcast();

  static Stream<dynamic> get events => _eventController.stream;

  static Object? get _bridge =>
      js_util.getProperty(js_util.globalThis, 'UzitaNeshanMap');

  static void _ensureEventHook() {
    if (_eventsHooked) return;
    _eventsHooked = true;
    final bridge = _bridge;
    if (bridge == null) return;
    js_util.callMethod<void>(bridge, 'setEventCallback', [
      js_util.allowInterop((dynamic payload) {
        _eventController.add(payload);
      }),
    ]);
  }

  static Future<void> invokeMethod(
    String method,
    Map<String, dynamic> arguments,
  ) async {
    _ensureEventHook();
    final bridge = _bridge;
    if (bridge == null) {
      debugPrint('[UzitaNeshanMap] bridge not loaded');
      return;
    }

    final viewId = arguments['viewId'];
    try {
      switch (method) {
        case 'moveCamera':
        case 'beginNavigationCamera':
        case 'updateNavigationCamera':
        case 'fitBounds':
        case 'updateRoute':
        case 'updateDriverMarker':
          js_util.callMethod<void>(bridge, method, [viewId, arguments]);
        case 'setNavigationFollow':
          js_util.callMethod<void>(bridge, method, [
            viewId,
            arguments['enabled'] ?? false,
          ]);
        case 'setOverviewGestures':
          js_util.callMethod<void>(bridge, method, [
            viewId,
            arguments['enabled'] ?? false,
          ]);
        default:
          debugPrint('[UzitaNeshanMap] unknown method: $method');
      }
    } catch (e) {
      debugPrint('[UzitaNeshanMap] $method failed: $e');
    }
  }

  static Future<void> createMap({
    required int viewId,
    required String containerId,
    required String mapKey,
    required bool isDark,
  }) async {
    _ensureEventHook();
    final bridge = _bridge;
    if (bridge == null) return;
    js_util.callMethod<void>(bridge, 'createMap', [
      viewId,
      containerId,
      mapKey,
      isDark,
    ]);
  }

  static Future<void> destroyMap(int viewId) async {
    final bridge = _bridge;
    if (bridge == null) return;
    js_util.callMethod<void>(bridge, 'destroyMap', [viewId]);
  }
}
