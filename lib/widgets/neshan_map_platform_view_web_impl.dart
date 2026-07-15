import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:uzita/services/neshan_map_bindings.dart';
import 'package:uzita/utils/neshan_config.dart';

/// HtmlElementView hosting the Neshan Mapbox GL map on web.
class NeshanWebMapPlatformView extends StatefulWidget {
  final bool isDark;
  final ValueChanged<int> onPlatformViewCreated;

  const NeshanWebMapPlatformView({
    super.key,
    required this.isDark,
    required this.onPlatformViewCreated,
  });

  @override
  State<NeshanWebMapPlatformView> createState() =>
      _NeshanWebMapPlatformViewState();
}

class _NeshanWebMapPlatformViewState extends State<NeshanWebMapPlatformView> {
  static int _nextViewId = 1;
  late final int _viewId;
  late final String _containerId;
  late final String _viewType;
  bool _registered = false;
  bool _mapInitialized = false;

  @override
  void initState() {
    super.initState();
    _viewId = _nextViewId++;
    _containerId = 'uzita-neshan-map-$_viewId';
    _viewType = 'uzita-neshan-map-$_viewId';
  }

  @override
  void dispose() {
    unawaited(NeshanMapBindings.destroyMap(_viewId));
    super.dispose();
  }

  void _registerViewFactory() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = html.DivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden';
      return div;
    });
  }

  Future<void> _initMap() async {
    if (_mapInitialized) return;
    final mapKey = effectiveNeshanMapKey;
    if (mapKey.isEmpty) return;
    _mapInitialized = true;
    await NeshanMapBindings.createMap(
      viewId: _viewId,
      containerId: _containerId,
      mapKey: mapKey,
      isDark: widget.isDark,
    );
    widget.onPlatformViewCreated(_viewId);
  }

  @override
  Widget build(BuildContext context) {
    _registerViewFactory();
    if (!_mapInitialized && effectiveNeshanMapKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initMap());
      });
    }

    if (effectiveNeshanMapKey.isEmpty) {
      return const ColoredBox(
        color: Color(0xFFE8EEF4),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'NESHAN_MAP_KEY is not configured',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
