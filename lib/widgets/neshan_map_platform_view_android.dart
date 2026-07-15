import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Widget buildNeshanMapPlatformView({
  required bool isDark,
  required ValueChanged<int> onPlatformViewCreated,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  return AndroidView(
    viewType: 'com.example.uzita/neshan_map_view',
    creationParams: {'isDark': isDark},
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: onPlatformViewCreated,
    gestureRecognizers: gestureRecognizers,
  );
}
