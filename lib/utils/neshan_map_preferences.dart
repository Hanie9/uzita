import 'package:shared_preferences/shared_preferences.dart';

/// Persisted Neshan driver-map theme (independent of app dark mode).
class NeshanMapPreferences {
  static const _darkModeKey = 'neshanDriverMapDarkMode';

  static Future<bool> isDarkModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static Future<void> setDarkModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }
}
