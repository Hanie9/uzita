import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Create animations
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Start logo animation
    await _logoController.forward();

    // Start text animation after logo
    await _textController.forward();

    // Wait a bit then navigate
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Check if session is expired using session manager
    final sessionManager = SessionManager();
    final expired = await sessionManager.isSessionExpired();

    if (expired && token != null) {
      await sessionManager.endSession();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              (!expired && token != null) ? HomeScreen() : const LoginScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;
    // Scale assets and text for different phone sizes
    final double logoHeight = (shortest * 0.55).clamp(140.0, 260.0);
    final double logoWidth = (shortest * 1.1).clamp(260.0, 520.0);
    final double brandTitle = (shortest * 0.15).clamp(22.0, 34.0);
    final double brandSub = (shortest * 0.085).clamp(14.0, 20.0);
    final double uzitaSize = (shortest * 0.17).clamp(44.0, 70.0);
    final double spacing1 = (size.height * 0.035).clamp(16.0, 36.0);
    final double spacing2 = (size.height * 0.02).clamp(10.0, 24.0);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with logo
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main logo with animation
                      AnimatedBuilder(
                        animation: _logoAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoAnimation.value,
                            child: Image.asset(
                              'assets/biokaveh.png',
                              height: logoHeight,
                              width: logoWidth,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),

                      SizedBox(height: spacing1),

                      // Brand text with animation
                      AnimatedBuilder(
                        animation: _textAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _textAnimation.value,
                            child: Column(
                              children: [
                                Text(
                                  'ELARRO',
                                  style: TextStyle(
                                    fontSize: brandTitle,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.lapisLazuli,
                                    letterSpacing: 4,
                                    fontFamily: 'Nasalization',
                                  ),
                                ),
                                SizedBox(height: spacing2),
                                Text(
                                  'BIOKAVEH',
                                  style: TextStyle(
                                    fontSize: brandSub,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.color ??
                                        Colors.black,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                    fontFamily: 'Nasalization',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom section with app info
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Uzita logo
                    Image.asset(
                      'assets/logouzita.png',
                      height: uzitaSize,
                      width: uzitaSize,
                    ),
                    SizedBox(height: spacing2),
                    Text(
                      AppLocalizations.of(context)!.splash_version,
                      style: TextStyle(
                        fontSize: (brandSub * 0.78).clamp(12.0, 16.0),
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7) ??
                            Colors.grey[500],
                      ),
                    ),
                    SizedBox(height: spacing1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
