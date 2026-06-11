import 'package:flutter/material.dart';
import 'package:uzita/services/neshan_models.dart';

IconData maneuverIcon(NeshanRouteStep step) {
  final type = step.stepType?.toLowerCase() ?? '';
  final modifier = step.modifier?.toLowerCase() ?? '';
  final text = step.instruction.toLowerCase();

  if (type == 'arrive' || text.contains('رسیدن')) {
    return Icons.flag;
  }
  if (type == 'depart' || text.contains('حرکت') || text.contains('مبدا')) {
    return Icons.play_arrow_rounded;
  }
  if (text.contains('راست') ||
      modifier.contains('right') ||
      type.contains('right')) {
    return Icons.turn_right;
  }
  if (text.contains('چپ') || modifier.contains('left') || type.contains('left')) {
    return Icons.turn_left;
  }
  if (text.contains('دور برگرد') || text.contains('uturn')) {
    return Icons.u_turn_left;
  }
  if (text.contains('میدان') || type.contains('roundabout')) {
    return Icons.roundabout_left;
  }
  if (text.contains('ادغام') || type.contains('merge')) {
    return Icons.merge;
  }
  return Icons.straight;
}

String formatManeuverDistance(double meters, {required bool persian}) {
  if (meters < 50) {
    return persian ? 'هم‌اکنون' : 'Now';
  }
  if (meters < 1000) {
    final rounded = (meters / 50).round() * 50;
    return persian ? '$rounded متر' : '$rounded m';
  }
  final km = (meters / 1000).toStringAsFixed(1);
  return persian ? '$km کیلومتر' : '$km km';
}

String maneuverDistancePrefix(double meters, {required bool persian}) {
  if (meters < 50) {
    return persian ? 'اکنون' : 'Now';
  }
  final dist = formatManeuverDistance(meters, persian: persian);
  return persian ? 'در $dist' : 'In $dist';
}
