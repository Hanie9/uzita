import 'package:flutter/widgets.dart';

/// UiScale: simple helper for adaptive sizes across small/large phones
class UiScale {
  final Size size;
  final double shortest;

  UiScale(BuildContext context)
    : size = MediaQuery.of(context).size,
      shortest = MediaQuery.of(context).size.shortestSide;

  bool get isVerySmallPhone => shortest <= 340;
  bool get isSmallPhone => shortest > 340 && shortest <= 360;
  bool get isLargePhone => shortest >= 420 && shortest < 480;
  bool get isVeryLargePhone => shortest >= 480;

  double scale({required double base, double? min, double? max}) {
    double factor;
    if (isVerySmallPhone) {
      factor = 0.9;
    } else if (isSmallPhone) {
      factor = 0.95;
    } else if (isVeryLargePhone) {
      factor = 1.12;
    } else if (isLargePhone) {
      factor = 1.06;
    } else {
      factor = 1.0;
    }
    final value = base * factor;
    if (min != null && value < min) return min;
    if (max != null && value > max) return max;
    return value;
  }
}
