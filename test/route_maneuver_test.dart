import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/utils/route_maneuver.dart';

void main() {
  group('route_maneuver', () {
    test('guidancePrimaryLabel prefers turn instruction over street name', () {
      const step = NeshanRouteStep(
        instruction: 'به سمت بلوار شهید ثانی، به راست بپیچید',
        name: 'بلوار شهید ثانی',
        distanceText: '',
        durationText: '',
        stepType: 'turn',
        modifier: 'right',
      );

      expect(
        guidancePrimaryLabel(step),
        'به سمت بلوار شهید ثانی، به راست بپیچید',
      );
    });

    test('maneuverIcon maps right turn modifier to turn_right icon', () {
      const step = NeshanRouteStep(
        instruction: 'به راست بپیچید',
        name: 'خیابان آزادی',
        distanceText: '',
        durationText: '',
        stepType: 'turn',
        modifier: 'right',
      );

      expect(maneuverIcon(step), Icons.turn_right);
    });

    test('maneuverIcon maps left turn from Persian instruction', () {
      const step = NeshanRouteStep(
        instruction: 'به چپ بپیچید و وارد خیابان ولیعصر شوید',
        name: 'ولیعصر',
        distanceText: '',
        durationText: '',
        stepType: 'turn',
        modifier: 'left',
      );

      expect(maneuverIcon(step), Icons.turn_left);
    });

    test('maneuverIcon maps continue straight to upward arrow', () {
      const step = NeshanRouteStep(
        instruction: 'به مسیر خود ادامه دهید',
        name: 'بلوار کشاورز',
        distanceText: '',
        durationText: '',
        stepType: 'continue',
      );

      expect(maneuverIcon(step), Icons.arrow_upward_rounded);
    });

    test('maneuverIcon does not treat street name راست as right turn', () {
      const step = NeshanRouteStep(
        instruction: 'در بلوار شهید راستی به مسیر خود ادامه دهید',
        name: 'بلوار شهید راستی',
        distanceText: '',
        durationText: '',
        stepType: 'continue',
      );

      expect(maneuverIcon(step), Icons.arrow_upward_rounded);
    });
  });
}
