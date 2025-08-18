import 'package:flutter/material.dart';

// Export the screens
export 'screens/service_list_screen.dart';
export 'screens/send_service_screen.dart';

// Colors
class AppColors {
  static const Color bronzeGold = Color(
    0xFF007BA7,
  ); // Changed from gold to blue
  static const Color emerald = Color(0xFF007BA7); // Changed from green to blue
  static const Color maroon = Color(0xFF007BA7); // Changed to blue
  static const Color iranianGray = Color(0xFF708090);
  static const Color tan = Color(0xFF007BA7); // Changed to blue
  static const Color lapisLazuli = Color(0xFF007BA7);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}

// Constants
const String baseUrl5 = 'https://uzita-iot.ir/api';
const double kSpacing = 20.0;
const double kRadius = 16.0;
const double kIconSize = 28.0;
