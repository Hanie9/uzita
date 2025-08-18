import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'fa';
  double _textSize = 1.0;
  bool _isLoading = true;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  String get selectedLanguage => _selectedLanguage;
  double get textSize => _textSize;
  bool get isLoading => _isLoading;

  ThemeData get currentTheme => _darkModeEnabled ? darkTheme : lightTheme;

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF007BA7),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.grey[800]),
      titleTextStyle: TextStyle(
        color: Colors.grey[800],
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF007BA7);
        }
        return Colors.grey[400];
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF007BA7).withValues(alpha: 0.5);
        }
        return Colors.grey[300];
      }),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.grey[800]),
      bodyMedium: TextStyle(color: Colors.grey[600]),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF007BA7),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF2C2C2C),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF007BA7);
        }
        return Colors.grey[600];
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF007BA7).withValues(alpha: 0.5);
        }
        return Colors.grey[800];
      }),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );

  Future<void> loadSettings() async {
    print('DEBUG: [SettingsProvider] Loading settings from SharedPreferences');
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _notificationsEnabled =
        prefs.getBool('notificationsEnabled') ?? _notificationsEnabled;
    _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? _darkModeEnabled;

    final savedLanguage = prefs.getString('selectedLanguage');
    print(
      'DEBUG: [SettingsProvider] Saved language from SharedPreferences: $savedLanguage',
    );
    _selectedLanguage = savedLanguage ?? _selectedLanguage;
    print('DEBUG: [SettingsProvider] Using language: $_selectedLanguage');

    _textSize = prefs.getDouble('textSize') ?? _textSize;
    _isLoading = false;
    notifyListeners();
    print('DEBUG: [SettingsProvider] Settings loaded and listeners notified');
  }

  Future<void> setDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode_enabled', value);
      _darkModeEnabled = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting dark mode: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    if (language != _selectedLanguage) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', language);

      // Update the language without triggering a full rebuild
      _selectedLanguage = language;

      // Only notify listeners after the SharedPreferences update is complete
      notifyListeners();
    }
  }

  // Helper method to get the current text direction
  TextDirection get textDirection {
    return _selectedLanguage == 'en' ? TextDirection.ltr : TextDirection.rtl;
  }

  // String _normalizeLanguage(String? raw) {
  //   final value = (raw ?? '').trim().toLowerCase();
  //   if (value == 'fa' ||
  //       value == 'farsi' ||
  //       value == 'فارسی' ||
  //       value == 'persian') {
  //     return 'fa';
  //   }
  //   if (value == 'en' || value == 'english') return 'en';
  //   return 'fa';
  // }

  Future<void> setTextSize(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('text_size', value);
      _textSize = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting text size: $e');
    }
  }

  Future<void> setNotifications(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
      _notificationsEnabled = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting notifications: $e');
    }
  }
}
