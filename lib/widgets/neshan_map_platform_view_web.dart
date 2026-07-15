import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uzita/widgets/neshan_map_platform_view_web_impl.dart';

Widget buildNeshanMapPlatformView({
  required bool isDark,
  required ValueChanged<int> onPlatformViewCreated,
  required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
}) {
  return NeshanWebMapPlatformView(
    isDark: isDark,
    onPlatformViewCreated: onPlatformViewCreated,
  );
}
