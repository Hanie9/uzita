import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/screens/command_list_screen.dart';
import 'package:uzita/screens/device_list_screen.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/screens/profile_screen.dart';
import 'package:uzita/screens/settings_screen.dart';
import 'package:uzita/screens/splash_screen.dart';
import 'package:uzita/screens/user_list_screen.dart';
import 'dart:async';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/api_config.dart';

final String baseUrl = apiBaseUrl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SettingsProvider
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Ensure the system UI overlay style is enforced
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  // Ensure Google Fonts are ready on web before first paint to match Android look
  // and avoid font swapping in PWA.
  await GoogleFonts.pendingFonts();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => settingsProvider,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  @override
  void initState() {
    super.initState();
    print('DEBUG: [MyApp] initState called');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        // Create locale based on selected language
        final locale = Locale(settings.selectedLanguage);

        print('''[MyApp] Building MaterialApp with:
  - Selected Language: ${settings.selectedLanguage}
  - Locale: ${locale.languageCode}
  - Text Direction: ${settings.selectedLanguage == 'en' ? 'LTR' : 'RTL'}
''');

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Uzita',
          theme: settings.currentTheme,
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: locale, // Force our selected locale
          builder: (context, child) {
            print('[MyApp] Builder called with:');
            print(
              '  - Locale: ${Localizations.localeOf(context).languageCode}',
            );
            print(
              '  - Text Direction: ${settings.selectedLanguage == 'en' ? 'LTR' : 'RTL'}',
            );

            // Apply text scaling and direction
            // Set the text direction based on the current locale
            final textDirection =
                Localizations.localeOf(context).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl;

            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(settings.textSize)),
              child: Directionality(
                textDirection: textDirection,
                child: SessionTimeoutWrapper(child: child!),
              ),
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => SplashScreen(),
            '/home': (context) => HomeScreen(),
            '/devices': (context) => DeviceListScreen(),
            '/commands': (context) => CommandListScreen(),
            '/reports': (context) =>
                CommandListScreen(), // Same screen as commands, but filtered for level 3 users
            '/users': (context) => UserListScreen(),
            '/settings': (context) => SettingsScreen(),
            '/profile': (context) => ProfileScreen(),
          },
        );
      },
    );
  }
}

class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;
  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper>
    with WidgetsBindingObserver {
  final SessionManager _sessionManager = SessionManager();
  StreamSubscription<bool>? _sessionStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSessionManager();
  }

  Future<void> _initializeSessionManager() async {
    await _sessionManager.initialize();

    // Listen to session state changes
    _sessionStateSubscription = _sessionManager.sessionStateStream.listen((
      isActive,
    ) {
      if (!isActive && mounted) {
        _navigateToLogin();
      }
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _sessionManager.onAppLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _sessionManager.updateActivity(),
      onPointerMove: (_) => _sessionManager.updateActivity(),
      onPointerUp: (_) => _sessionManager.updateActivity(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
