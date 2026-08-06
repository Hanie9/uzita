import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Web: JS bridge to [web/neshan_map_bridge.js] + Neshan Mapbox GL SDK.
class NeshanMapBindings {
  NeshanMapBindings._();

  static bool _eventsHooked = false;
  static final StreamController<dynamic> _eventController =
      StreamController<dynamic>.broadcast();

  static Stream<dynamic> get events => _eventController.stream;

  static JSObject? get _bridge => globalContext['UzitaNeshanMap'] as JSObject?;

  static void _ensureEventHook() {
    if (_eventsHooked) return;
    _eventsHooked = true;
    final bridge = _bridge;
    if (bridge == null) return;
    bridge.callMethodVarArgs<JSAny?>('setEventCallback'.toJS, [
      ((JSAny? payload) {
        _eventController.add(payload?.dartify());
      }).toJS,
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
          bridge.callMethodVarArgs<JSAny?>(method.toJS, [
            viewId.jsify(),
            arguments.jsify(),
          ]);
        case 'setNavigationFollow':
          bridge.callMethodVarArgs<JSAny?>(method.toJS, [
            viewId.jsify(),
            ((arguments['enabled'] as bool?) ?? false).toJS,
          ]);
        case 'setOverviewGestures':
          bridge.callMethodVarArgs<JSAny?>(method.toJS, [
            viewId.jsify(),
            ((arguments['enabled'] as bool?) ?? false).toJS,
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
    bridge.callMethodVarArgs<JSAny?>('createMap'.toJS, [
      viewId.toJS,
      containerId.toJS,
      mapKey.toJS,
      isDark.toJS,
    ]);
  }

  static Future<void> destroyMap(int viewId) async {
    final bridge = _bridge;
    if (bridge == null) return;
    bridge.callMethodVarArgs<JSAny?>('destroyMap'.toJS, [viewId.toJS]);
  }
}
