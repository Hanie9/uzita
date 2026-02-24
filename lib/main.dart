import 'package:flutter/material.dart';
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
import 'package:uzita/screens/service_provider_services_screen.dart';
import 'package:uzita/screens/service_provider_service_detail_screen.dart';
import 'package:uzita/screens/technician_tasks_screen.dart';
import 'package:uzita/screens/technician_task_detail_screen.dart';
import 'package:uzita/screens/technician_reports_screen.dart';
import 'package:uzita/screens/transport_requests_screen.dart';
import 'package:uzita/screens/driver_public_loads_screen.dart';
import 'package:uzita/screens/driver_missions_screen.dart';
import 'package:uzita/screens/driver_reports_screen.dart';
import 'package:uzita/screens/driver_task_detail_screen.dart';
import 'package:uzita/screens/technician_organ_tasks_screen.dart';
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

  // Local fonts are already loaded from assets, no need to wait for Google Fonts

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

            // Adaptive text scaling for small/large phones
            final mq = MediaQuery.of(context);
            final shortestSide = mq.size.shortestSide;
            double deviceAdjustment;
            if (shortestSide <= 340) {
              deviceAdjustment = 0.92; // very small phones
            } else if (shortestSide <= 360) {
              deviceAdjustment = 0.96; // small phones
            } else if (shortestSide >= 480) {
              deviceAdjustment = 1.08; // large phones / small tablets
            } else if (shortestSide >= 420) {
              deviceAdjustment = 1.04; // larger phones
            } else {
              deviceAdjustment = 1.0; // normal phones
            }
            final double effectiveTextScale =
                (settings.textSize * deviceAdjustment).clamp(0.9, 1.15);

            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(effectiveTextScale),
              ),
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
            '/service-provider-services': (context) =>
                ServiceProviderServicesScreen(),
            '/technician-organ-tasks': (context) =>
                const TechnicianOrganTasksScreen(),
            '/service-provider-service-detail': (context) {
              final service =
                  ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
              return ServiceProviderServiceDetailScreen(service: service);
            },
            '/technician-tasks': (context) => TechnicianTasksScreen(),
            '/technician-task-detail': (context) {
              final task =
                  ModalRoute.of(context)!.settings.arguments
                      as Map<String, dynamic>;
              return TechnicianTaskDetailScreen(task: task);
            },
            '/technician-reports': (context) => TechnicianReportsScreen(),
            '/transport-requests': (context) =>
                const TransportRequestsScreen(),
            '/transport-public-loads': (context) =>
                const DriverPublicLoadsScreen(),
            '/driver-missions': (context) => const DriverMissionsScreen(),
            '/driver-reports': (context) => const DriverReportsScreen(),
            '/driver-task-detail': (context) {
              final args =
                  ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              // Check if arguments contain 'task' key (new format) or is the task itself (old format)
              final task = args['task'] as Map<String, dynamic>? ?? args;
              final isReport = args['isReport'] as bool? ?? false;
              return DriverTaskDetailScreen(task: task, isReport: isReport);
            },
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
