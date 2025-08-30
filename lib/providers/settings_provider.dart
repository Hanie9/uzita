import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  ThemeData get currentTheme {
    final ThemeData baseTheme = _darkModeEnabled ? darkTheme : lightTheme;
    final bool isFarsi = _selectedLanguage != 'en';

    // Choose high-quality, web-friendly fonts for each language
    final TextTheme themedText = isFarsi
        ? GoogleFonts.vazirmatnTextTheme(baseTheme.textTheme)
        : GoogleFonts.interTextTheme(baseTheme.textTheme);

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    final ButtonStyle commonButtonStyle = ButtonStyle(
      // Avoid infinite width from Size.fromHeight which sets width to double.infinity
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: WidgetStatePropertyAll(
        themedText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    final ColorScheme colorScheme = baseTheme.colorScheme;

    return baseTheme.copyWith(
      textTheme: themedText,
      // Make spacing more compact across the app by default
      visualDensity: const VisualDensity(horizontal: 0.0, vertical: -0.2),
      listTileTheme: const ListTileThemeData(
        dense: true,
        minLeadingWidth: 28,
        horizontalTitleGap: 10,
        minVerticalPadding: 6,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      // Unify card look & spacing across app
      cardTheme: baseTheme.cardTheme.copyWith(
        margin: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Consistent, compact dialogs on all phones
      dialogTheme: baseTheme.dialogTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titleTextStyle: themedText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: themedText.bodyMedium,
        backgroundColor: baseTheme.cardTheme.color,
      ),
      // For M2, dialogTheme is used for AlertDialog as well; keep one source
      bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
        backgroundColor: baseTheme.cardTheme.color,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: commonButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkModeEnabled ? Colors.grey[700] : Colors.grey[400];
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkModeEnabled ? Colors.white70 : Colors.white;
            }
            return colorScheme.onPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            colorScheme.onPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: commonButtonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
          foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: commonButtonStyle.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.primary, width: 1.4),
          ),
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          overlayColor: WidgetStatePropertyAll(
            colorScheme.primary.withValues(alpha: 0.06),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: commonButtonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(colorScheme.primary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: _darkModeEnabled ? const Color(0xFF1E1E1E) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        labelStyle: themedText.bodyMedium,
        hintStyle: themedText.bodyMedium?.copyWith(
          color: _darkModeEnabled ? Colors.white60 : Colors.grey[500],
        ),
      ),
    );
  }

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
    // Preload web fonts so PWA renders with correct typography from first frame.
    await _preloadFontsForSelectedLanguage();
    _isLoading = false;
    notifyListeners();
    print('DEBUG: [SettingsProvider] Settings loaded and listeners notified');
  }

  Future<void> _preloadFontsForSelectedLanguage() async {
    try {
      // Trigger font requests for the selected language and await readiness.
      final bool isFarsi = _selectedLanguage != 'en';
      if (isFarsi) {
        // Request creation triggers the font load via google_fonts on web.
        GoogleFonts.vazirmatn();
      } else {
        GoogleFonts.inter();
      }
      await GoogleFonts.pendingFonts();
    } catch (e) {
      debugPrint('DEBUG: [SettingsProvider] Font preload skipped: $e');
    }
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

      // Preload fonts for the newly selected language to avoid visual swaps
      // during the next frame. We do not block UI; fire-and-forget.
      // Ignore result; any failure falls back to default fonts.
      _preloadFontsForSelectedLanguage();

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
