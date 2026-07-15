import 'package:flutter/material.dart';
import 'package:uzita/services/neshan_models.dart';

bool isDepartOrContinueStep(NeshanRouteStep step) {
  final type = step.stepType?.toLowerCase() ?? '';
  if (type == 'depart' || type == 'continue' || type == 'new name') {
    return true;
  }
  final text = step.instruction.toLowerCase();
  if (text.contains('حرکت به سمت') ||
      text.contains('ادامه دهید') ||
      text.contains('continue on')) {
    return true;
  }
  return false;
}

bool isArrivalStep(NeshanRouteStep step) {
  final type = step.stepType?.toLowerCase() ?? '';
  if (type == 'arrive') return true;
  return step.instruction.contains('رسیدن') ||
      step.instruction.contains('مقصد');
}

bool isContinueStraightStep(NeshanRouteStep step) {
  if (isDepartOrContinueStep(step)) return true;

  final type = step.stepType?.toLowerCase() ?? '';
  final modifier = step.modifier?.toLowerCase() ?? '';
  if ((type == 'straight' || modifier == 'straight') &&
      modifier != 'left' &&
      modifier != 'right' &&
      !type.contains('left') &&
      !type.contains('right')) {
    return true;
  }

  final text = step.instruction.toLowerCase();
  if (text.contains('مستقیم') ||
      text.contains('ادامه دهید') ||
      text.contains('continue on') ||
      text.contains('continue straight') ||
      RegExp(r'head\s+(north|south|east|west)').hasMatch(text)) {
    return !_isExplicitTurnInstruction(text);
  }
  return false;
}

bool _isExplicitTurnInstruction(String text) {
  return RegExp(
    r'بپیچ|بچرخ|پیچید|turn\s+(left|right)|turn\s+slight',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _isRightTurn(NeshanRouteStep step) {
  final modifier = step.modifier?.toLowerCase() ?? '';
  final type = step.stepType?.toLowerCase() ?? '';
  if (modifier.contains('right') || type.contains('right')) return true;
  final text = step.instruction.toLowerCase();
  return RegExp(
    r'به\s*راست\s*بپیچ|راست\s*بپیچ|به\s*سمت\s*راست\s*بپیچ',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _isLeftTurn(NeshanRouteStep step) {
  final modifier = step.modifier?.toLowerCase() ?? '';
  final type = step.stepType?.toLowerCase() ?? '';
  if (modifier.contains('left') || type.contains('left')) return true;
  final text = step.instruction.toLowerCase();
  return RegExp(
    r'به\s*چپ\s*بپیچ|چپ\s*بپیچ|به\s*سمت\s*چپ\s*بپیچ',
    caseSensitive: false,
  ).hasMatch(text);
}

IconData maneuverIcon(NeshanRouteStep step) {
  final type = step.stepType?.toLowerCase() ?? '';
  final text = step.instruction.toLowerCase();

  if (isArrivalStep(step)) {
    return Icons.flag;
  }
  if (isContinueStraightStep(step)) {
    return Icons.arrow_upward_rounded;
  }
  if (type == 'depart' || text.contains('حرکت') || text.contains('مبدا')) {
    return Icons.arrow_upward_rounded;
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
  if (_isRightTurn(step)) {
    return Icons.turn_right;
  }
  if (_isLeftTurn(step)) {
    return Icons.turn_left;
  }
  return Icons.arrow_upward_rounded;
}

/// Navigation maneuver icon for the guidance card.
Widget maneuverIconWidget(
  NeshanRouteStep step, {
  required bool rtl,
  Color color = Colors.white,
  double size = 42,
}) {
  return Icon(
    maneuverIcon(step),
    color: color,
    size: size,
  );
}

String guidancePrimaryLabel(NeshanRouteStep step) {
  final instruction = step.instruction.trim();
  if (instruction.isNotEmpty) return instruction;
  return step.name.trim();
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
