import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/main.dart';
import 'package:uzita/services.dart';
import 'package:uzita/screens/user_register_screen.dart';
import 'package:uzita/screens/admin_register_screen.dart';
import 'package:uzita/services/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String error = '';
  bool rememberMe = false;
  // Biometric & secure storage
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool biometricsAvailable = false;
  bool hasStoredCredentials = false;
  bool biometricLoading = false;
  bool authAvailable = false; // biometrics or device credentials (PIN/Pattern)
  bool _autoPrompted =
      false; // ensure auto biometric prompt happens once per visit

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
    _initializeBiometricsState();
  }

  Future<void> _loadRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_username') ?? '';
    if (saved.isNotEmpty) {
      setState(() {
        usernameController.text = saved;
        rememberMe = true;
      });
    }
  }

  Future<void> _initializeBiometricsState() async {
    await Future.wait([
      _checkBiometricsAvailability(),
      _checkStoredCredentials(),
    ]);
    // Attempt automatic biometric prompt on login screen (not splash)
    _maybeAutoPromptBiometric();
  }

  Future<void> _checkBiometricsAvailability() async {
    if (kIsWeb) {
      setState(() {
        biometricsAvailable = false;
        authAvailable = false;
      });
      return;
    }
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      setState(() {
        biometricsAvailable = canCheck && isSupported;
        authAvailable = isSupported; // allow device credentials fallback
      });
    } catch (_) {
      setState(() {
        biometricsAvailable = false;
        authAvailable = false;
      });
    }
  }

  Future<void> _checkStoredCredentials() async {
    try {
      final savedUser = await _secureStorage.read(key: 'bio_username');
      final savedPass = await _secureStorage.read(key: 'bio_password');
      setState(
        () => hasStoredCredentials =
            (savedUser != null &&
            savedUser.isNotEmpty &&
            savedPass != null &&
            savedPass.isNotEmpty),
      );
    } catch (_) {
      setState(() => hasStoredCredentials = false);
    }
  }

  void _maybeAutoPromptBiometric() {
    if (_autoPrompted) return;
    if (!mounted) return;
    if (!authAvailable) return;
    if (!hasStoredCredentials) return;
    _autoPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !biometricLoading) {
        _tryBiometricLogin();
      }
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() => loading = true);

    try {
      // Ensure any previous session is fully cleared before new login
      final prefs = await SharedPreferences.getInstance();
      // Preserve saved username and selected language before clearing
      final preservedSavedUsername = prefs.getString('saved_username');
      final preservedLanguage = prefs.getString('selectedLanguage');
      await prefs.clear();
      if (preservedSavedUsername != null && preservedSavedUsername.isNotEmpty) {
        await prefs.setString('saved_username', preservedSavedUsername);
      }
      if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
        await prefs.setString('selectedLanguage', preservedLanguage);
      }

      final enteredUsername = usernameController.text.trim();
      final enteredPassword = passwordController.text; // do not trim passwords

      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
        body: json.encode({
          'username': enteredUsername,
          'password': enteredPassword,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await prefs.setString('token', data['token']);
        await prefs.setString('phone', data['phone'] ?? '');
        await prefs.setString('username', enteredUsername);
        // Start session timers for 15-minute timeout/inactivity
        try {
          await SessionManager().startSession();
        } catch (_) {}
        // Store credentials securely for biometric login in future sessions
        try {
          if (enteredUsername.isNotEmpty && enteredPassword.isNotEmpty) {
            await _secureStorage.write(
              key: 'bio_username',
              value: enteredUsername,
            );
            await _secureStorage.write(
              key: 'bio_password',
              value: enteredPassword,
            );
            setState(() => hasStoredCredentials = true);
          }
        } catch (_) {}
        if (rememberMe) {
          await prefs.setString('saved_username', enteredUsername);
        } else {
          await prefs.remove('saved_username');
        }

        // Fetch user data after successful login
        try {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final userDataResponse = await http.get(
            Uri.parse('$baseUrl/load_data_user/?ts=$ts'),
            headers: {
              'Authorization': 'Bearer ${data['token']}',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              'Connection': 'close',
            },
          );

          if (userDataResponse.statusCode == 200) {
            final userData = json.decode(
              utf8.decode(userDataResponse.bodyBytes),
            );

            final returnedUsername = (userData['user']?['username'] ?? '')
                .toString();

            // Store user level, active status, and modir flag
            await prefs.setInt('level', userData['level'] ?? 3);
            await prefs.setBool('active', userData['active'] ?? false);
            await prefs.setBool('modir', userData['modir'] ?? false);
            await prefs.setString('username', returnedUsername);

            // Safety check: ensure the account we logged into matches the entered username
            if (returnedUsername.isNotEmpty &&
                returnedUsername.toLowerCase() !=
                    enteredUsername.toLowerCase()) {
              final preservedSavedUsername = prefs.getString('saved_username');
              final preservedLanguage = prefs.getString('selectedLanguage');
              await prefs.clear();
              if (preservedSavedUsername != null &&
                  preservedSavedUsername.isNotEmpty) {
                await prefs.setString('saved_username', preservedSavedUsername);
              }
              if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
                await prefs.setString('selectedLanguage', preservedLanguage);
              }
              setState(
                () =>
                    error = AppLocalizations.of(context)!.login_error_username,
              );
              setState(() => loading = false);
              return;
            }
          } else {
            // Set defaults if user data fetch fails
            await prefs.setInt('level', 3);
            await prefs.setBool('active', false);
            await prefs.setBool('modir', false);
          }
        } catch (e) {
          // Set defaults if user data fetch fails
          await prefs.setInt('level', 3);
          await prefs.setBool('active', false);
          await prefs.setBool('modir', false);
        }

        // Mark login time for session TTL
        await prefs.setInt(
          'login_at_epoch_ms',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Start session management
        await SessionManager().startSession();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        setState(
          () => error =
              data['detail'] ?? AppLocalizations.of(context)!.login_error,
        );
      }
    } catch (e) {
      setState(
        () => error = AppLocalizations.of(context)!.login_error_connecting,
      );
    }

    setState(() => loading = false);
  }

  Future<void> _tryBiometricLogin() async {
    final isSupported = await _localAuth.isDeviceSupported();
    if (!isSupported) {
      setState(
        () => error = AppLocalizations.of(context)!.login_no_authentication,
      );
      return;
    }
    final savedUser = await _secureStorage.read(key: 'bio_username');
    final savedPass = await _secureStorage.read(key: 'bio_password');
    if (savedUser == null ||
        savedUser.isEmpty ||
        savedPass == null ||
        savedPass.isEmpty) {
      setState(
        () => error = AppLocalizations.of(
          context,
        )!.login_with_username_and_Password,
      );
      return;
    }
    setState(() {
      biometricLoading = true;
      error = '';
    });
    try {
      // Allow device credentials if biometrics not available
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      if (!canCheck && available.isEmpty) {
        // Will fall back to device credentials in the prompt
      }
      final didAuth = await _localAuth.authenticate(
        localizedReason: AppLocalizations.of(context)!.login_authentication,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
        authMessages: [
          AndroidAuthMessages(
            signInTitle: AppLocalizations.of(context)!.login_account,
            cancelButton: AppLocalizations.of(context)!.login_cancle,
            biometricHint: AppLocalizations.of(context)!.login_add_finger,
            biometricNotRecognized: AppLocalizations.of(
              context,
            )!.login_no_access_fingerprint,
            biometricRequiredTitle: AppLocalizations.of(
              context,
            )!.login_need_authentication,
            deviceCredentialsRequiredTitle: AppLocalizations.of(
              context,
            )!.login_need_lock,
            deviceCredentialsSetupDescription: AppLocalizations.of(
              context,
            )!.login_active_lock,
            goToSettingsButton: AppLocalizations.of(context)!.login_settings,
            goToSettingsDescription: AppLocalizations.of(
              context,
            )!.login_active_lock,
          ),
        ],
      );
      if (didAuth) {
        // Populate controllers and reuse existing login flow
        usernameController.text = savedUser;
        passwordController.text = savedPass;
        setState(() => biometricLoading = false);
        await login();
      }
    } on PlatformException catch (e) {
      String message = AppLocalizations.of(context)!.login_error_fingerprint;
      switch (e.code) {
        case 'NotAvailable':
          message = AppLocalizations.of(
            context,
          )!.login_fingerprint_not_available;
          break;
        case 'NotEnrolled':
          message = AppLocalizations.of(
            context,
          )!.login_fingerprint_not_enrolled;
          break;
        case 'PasscodeNotSet':
          message = AppLocalizations.of(context)!.login_fingerprint_not_set;
          break;
        case 'LockedOut':
          message = AppLocalizations.of(context)!.login_fingerprint_locked_out;
          break;
        case 'PermanentlyLockedOut':
          message = AppLocalizations.of(
            context,
          )!.login_fingerprint_permanently_locked_out;
          break;
        default:
          message =
              '${AppLocalizations.of(context)!.login_fingerprint_error}: ${e.code}';
      }
      setState(() => error = message);
    } catch (e) {
      setState(
        () => error = AppLocalizations.of(context)!.login_fingerprint_error,
      );
    }
    if (mounted) setState(() => biometricLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final double horizontalPadding = (screenWidth * 0.06).clamp(12.0, 24.0);
    final double logoHeight = (screenHeight * 0.22).clamp(120.0, 220.0);
    final double svgHeight = (logoHeight * 1.2).clamp(140.0, 300.0);
    final double svgWidth = (screenWidth * 0.9).clamp(240.0, 520.0);
    final double spacingAfterLogo = (screenHeight * 0.02).clamp(12.0, 24.0);
    final double fieldHeight = (screenHeight * 0.06).clamp(44.0, 56.0);
    final double fieldFontSize = (screenWidth * 0.035).clamp(13.0, 16.0);
    final double hintFontSize = (screenWidth * 0.04).clamp(14.0, 18.0);
    final double buttonHeight = fieldHeight;
    final double buttonFontSize = (screenWidth * 0.05).clamp(15.0, 18.0);
    final double fingerprintSize = (screenWidth * 0.18).clamp(56.0, 88.0);

    // Handle optional prefill from splash biometric flow
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      final prefillUsername = (routeArgs['prefill_username'] ?? '').toString();
      final prefillPassword = (routeArgs['prefill_password'] ?? '').toString();
      final autoLogin = routeArgs['auto_login'] == true;
      if (prefillUsername.isNotEmpty && prefillPassword.isNotEmpty) {
        usernameController.text = prefillUsername;
        passwordController.text = prefillPassword;
        if (autoLogin && !loading) {
          // trigger login once per open
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !loading) login();
          });
        }
      }
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: true, // Add this line
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            // Add this wrapper
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    bottom: screenHeight * 0.06,
                  ),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Image.asset(
                                'assets/logouzita.png',
                                height: screenHeight * 0.08,
                                width: screenHeight * 0.08,
                              ),
                            ],
                          ),
                          SizedBox(
                            height: logoHeight + 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Main logo image at the top
                                Positioned(
                                  top: -logoHeight * 0.3,
                                  child: Image.asset(
                                    'assets/biokaveh.png',
                                    height: svgHeight,
                                    width: svgWidth,
                                    fit: BoxFit.contain,
                                  ),
                                ),

                                // ELARRO text in gold/bronze in the middle
                                Positioned(
                                  top: logoHeight * 0.44,
                                  child: Builder(
                                    builder: (_) {
                                      final double elarroFontSize =
                                          (screenWidth * 0.08)
                                              .clamp(22.0, 32.0)
                                              .toDouble();
                                      return Text(
                                        'ELARRO',
                                        style: TextStyle(
                                          fontSize: elarroFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.lapisLazuli,
                                          letterSpacing: 4,
                                          fontFamily: 'Nasalization',
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                // BIOKAVEH text in black at the bottom
                                Positioned(
                                  top:
                                      (logoHeight * 0.38) +
                                      ((screenWidth * 0.08)
                                              .clamp(22.0, 32.0)
                                              .toDouble() *
                                          1.25) +
                                      6,
                                  child: Text(
                                    'BIOKAVEH',
                                    style: TextStyle(
                                      fontSize: (screenWidth * 0.045)
                                          .clamp(16.0, 22.0)
                                          .toDouble(),
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                      fontFamily: 'Nasalization',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: spacingAfterLogo),

                          // Username field
                          Container(
                            height: fieldHeight, // responsive height
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[600]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: TextField(
                              controller: usernameController,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: fieldFontSize),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(
                                  context,
                                )!.login_username,
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : const Color.fromARGB(255, 99, 97, 97),
                                  fontSize: hintFontSize,
                                ),
                                hintTextDirection: Directionality.of(context),
                                suffixIcon: Padding(
                                  padding: EdgeInsets.all(
                                    screenWidth * 0.02,
                                  ), // 2% of screen width
                                  child: SvgPicture.asset(
                                    'assets/icons/user.svg',
                                    colorFilter: ColorFilter.mode(
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? (Colors.grey[400] ?? Colors.grey)
                                          : const Color.fromARGB(
                                              255,
                                              80,
                                              77,
                                              77,
                                            ),
                                      BlendMode.srcIn,
                                    ),
                                    width:
                                        screenHeight *
                                        0.03, // 4% of screen height
                                    height:
                                        screenHeight *
                                        0.03, // 4% of screen height
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: (screenWidth * 0.035)
                                      .clamp(12.0, 16.0)
                                      .toDouble(),
                                  vertical: (screenHeight * 0.018)
                                      .clamp(10.0, 14.0)
                                      .toDouble(),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: screenHeight * 0.015,
                          ), // 1.5% of screen height
                          // Password field
                          Container(
                            height: fieldHeight, // responsive height
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[600]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: TextField(
                              controller: passwordController,
                              textAlign: TextAlign.center,
                              obscureText: true,
                              style: TextStyle(fontSize: fieldFontSize),
                              onSubmitted: (_) => loading ? null : login(),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(
                                  context,
                                )!.login_password,
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : const Color.fromARGB(255, 99, 97, 97),
                                  fontSize: hintFontSize,
                                ),
                                hintTextDirection: Directionality.of(context),
                                suffixIcon: Padding(
                                  padding: EdgeInsets.all(
                                    screenWidth * 0.02,
                                  ), // 2% of screen width
                                  child: SvgPicture.asset(
                                    'assets/icons/key.svg',
                                    colorFilter: ColorFilter.mode(
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? (Colors.grey[400] ?? Colors.grey)
                                          : const Color.fromARGB(
                                              255,
                                              80,
                                              77,
                                              77,
                                            ),
                                      BlendMode.srcIn,
                                    ),
                                    width:
                                        screenHeight *
                                        0.03, // 4% of screen height
                                    height:
                                        screenHeight *
                                        0.03, // 4% of screen height
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: (screenWidth * 0.035)
                                      .clamp(12.0, 16.0)
                                      .toDouble(),
                                  vertical: (screenHeight * 0.018)
                                      .clamp(10.0, 14.0)
                                      .toDouble(),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: screenHeight * 0.03,
                          ), // 3% of screen height
                          // Login button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.lapisLazuli.withValues(
                                    alpha: 0.5,
                                  ),
                                  spreadRadius: 2,
                                  blurRadius: 20,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: AbsorbPointer(
                                absorbing: loading,
                                child: ElevatedButton(
                                  onPressed: login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.lapisLazuli,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 1,
                                  ),
                                  child: loading
                                      ? SizedBox(
                                          height:
                                              screenHeight *
                                              0.022, // 2.2% of screen height
                                          width:
                                              screenHeight *
                                              0.022, // 2.2% of screen height
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            AppLocalizations.of(context)!.login,
                                            style: TextStyle(
                                              fontSize: buttonFontSize,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height: screenHeight * 0.02,
                          ), // 2.5% of screen height
                          // Remember me checkbox
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.login_remember_me,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[300]
                                      : const Color.fromARGB(255, 53, 52, 52),
                                  fontSize: (screenWidth * 0.04)
                                      .clamp(13.0, 16.0)
                                      .toDouble(),
                                ),
                              ),
                              SizedBox(
                                width: screenWidth * 0.02,
                              ), // 2% of screen width
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    rememberMe = !rememberMe;
                                  });
                                },
                                child: Container(
                                  width:
                                      screenHeight *
                                      0.02, // 2% of screen height
                                  height:
                                      screenHeight *
                                      0.02, // 2% of screen height
                                  decoration: BoxDecoration(
                                    color: rememberMe
                                        ? Color(0xFF007BA7)
                                        : Colors.white,
                                    border: Border.all(
                                      color: rememberMe
                                          ? Color(0xFF007BA7)
                                          : Colors.grey,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: rememberMe
                                      ? Icon(
                                          Icons.check,
                                          size: screenHeight * 0.015,
                                          color: Colors.white,
                                        ) // 1.5% of screen height
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height: screenHeight * 0.02,
                          ), // 3.5% of screen height
                          if (authAvailable)
                            Column(
                              children: [
                                GestureDetector(
                                  onTap:
                                      (loading ||
                                          biometricLoading ||
                                          !hasStoredCredentials)
                                      ? null
                                      : _tryBiometricLogin,
                                  child: Opacity(
                                    opacity:
                                        (loading ||
                                            biometricLoading ||
                                            !hasStoredCredentials)
                                        ? 0.5
                                        : 1.0,
                                    child: Container(
                                      width: fingerprintSize,
                                      height: fingerprintSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.lapisLazuli.withValues(
                                              alpha: 0.2,
                                            ),
                                            AppColors.lapisLazuli.withValues(
                                              alpha: 0.05,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: AppColors.lapisLazuli,
                                          width: 2,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: biometricLoading
                                          ? SizedBox(
                                              width: screenHeight * 0.013,
                                              height: screenHeight * 0.013,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 1,
                                                    color:
                                                        AppColors.lapisLazuli,
                                                  ),
                                            )
                                          : Icon(
                                              Icons.fingerprint,
                                              size: 40,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : AppColors.lapisLazuli,
                                            ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  hasStoredCredentials
                                      ? AppLocalizations.of(
                                          context,
                                        )!.login_biometric
                                      : AppLocalizations.of(
                                          context,
                                        )!.login_login_first,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.035,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : AppColors.lapisLazuli,
                                  ),
                                ),
                              ],
                            ),
                          // Error display
                          if (error.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                screenWidth * 0.025,
                              ), // 2.5% of screen width
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.red[900]?.withValues(alpha: 0.3)
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.red[600]!
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.red[300]
                                        : Colors.red,
                                    size: screenHeight * 0.025,
                                  ), // 2.5% of screen height
                                  SizedBox(
                                    width: screenWidth * 0.025,
                                  ), // 2.5% of screen width
                                  Expanded(
                                    child: Text(
                                      error,
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.red[300]
                                            : Colors.red.shade700,
                                        fontSize:
                                            screenWidth *
                                            0.035, // 3.5% of screen width
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(
                            height: 40,
                          ), // Add spacing to push buttons down
                          // Bottom registration buttons (responsive)
                          Builder(
                            builder: (ctx) {
                              final double availableWidth = MediaQuery.of(
                                ctx,
                              ).size.width;
                              final bool isNarrow = availableWidth < 480;

                              Widget userBtn = Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      spreadRadius: 1,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: 55,
                                  child: OutlinedButton(
                                    onPressed: loading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    UserRegisterScreen(),
                                              ),
                                            );
                                          },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[700]
                                          : Colors.grey[300],
                                      foregroundColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      side: BorderSide(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey[600]!
                                            : Colors.grey[400]!,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.login_user_register,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Icon(
                                          Icons.person_add_outlined,
                                          size: isNarrow ? 22 : 25,
                                          color: AppColors.bronzeGold,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              Widget adminBtn = Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      spreadRadius: 1,
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: 55,
                                  child: OutlinedButton(
                                    onPressed: loading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AdminregisterScreen(),
                                              ),
                                            );
                                          },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[700]
                                          : Colors.grey[300],
                                      foregroundColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      side: BorderSide(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey[600]!
                                            : Colors.grey[400]!,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.login_admin_register,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Icon(
                                          Icons.admin_panel_settings_outlined,
                                          size: isNarrow ? 22 : 25,
                                          color: AppColors.bronzeGold,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              return Row(
                                children: [
                                  Expanded(child: userBtn),
                                  SizedBox(width: 17),
                                  Expanded(child: adminBtn),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
