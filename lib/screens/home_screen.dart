import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/screens/command_list_screen.dart';
import 'package:uzita/screens/device_list_screen.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/settings_screen.dart';
import 'package:uzita/screens/user_list_screen.dart';
import 'package:uzita/screens/technician_reports_screen.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/shared_loading.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';
  int userLevel = 3;
  bool userActive = false; // تغییر پیش‌فرض به false
  bool userModir = false;
  bool isLoading = true; // اضافه کردن وضعیت loading
  bool showBanner = true; // اضافه کردن وضعیت نمایش بنر
  String userRoleTitle = '';
  String bannerUrl = '';
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Statistics data
  int activeDeviceCount = 0;
  int onlineUserCount = 0;
  int missionCount = 0; // For level 4 (technicians)

  // Add: Fetch and count active users
  Future<void> fetchAndCountActiveUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl/listuser/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );
      print('User count API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(
          utf8.decode(response.bodyBytes),
        );
        print('API Response type: ${responseData.runtimeType}');
        print('API Response: $responseData');

        // If backend sent an error object, do not force count=0
        if (responseData is Map && responseData['error'] != null) {
          final err = responseData['error'].toString();
          print('Users API error payload: $err');
          // For level 3, fallback to showing self as active
          if (userLevel >= 3) {
            if (mounted) {
              setState(() => onlineUserCount = 1);
            }
          } else {
            // For admins/representatives, keep previous count and optionally notify
            // Avoid overriding to 0; just leave current value
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(err)));
            }
          }
          return;
        }

        // Handle both List and Map response formats
        List users;
        if (responseData is List) {
          users = responseData;
        } else if (responseData is Map && responseData.containsKey('results')) {
          users = responseData['results'] ?? [];
        } else if (responseData is Map && responseData.containsKey('data')) {
          users = responseData['data'] ?? [];
        } else {
          print('Unexpected response format: $responseData');
          // Do not set to 0 on unexpected format; keep previous or fallback for level 3
          if (userLevel >= 3 && mounted) {
            setState(() => onlineUserCount = 1);
          }
          return;
        }

        print('Total users fetched: ${users.length}');
        int count = users.where((user) {
          try {
            return (user['active'] == true) || (user['is_active'] == true);
          } catch (_) {
            return false;
          }
        }).length;
        print('Active users count: $count');
        if (mounted) {
          setState(() {
            onlineUserCount = count;
          });
        }
      } else if (response.statusCode == 403) {
        // Permission denied
        if (userLevel >= 3 && mounted) {
          setState(() => onlineUserCount = 1);
        } else if (mounted) {
          // Admin/representative: keep previous count and show a hint
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.home_access_denies),
            ),
          );
        }
      } else {
        print('Failed to fetch users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching users: $e');
      // Fallback for level 3 users
      if (userLevel >= 3 && mounted) {
        setState(() {
          onlineUserCount = 1; // Show themselves as active
        });
      }
    }
  }

  // Add: Fetch and count active devices
  Future<void> fetchAndCountActiveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl/listdevice/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('Device count API response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List devices = json.decode(utf8.decode(response.bodyBytes));
        print('Total devices fetched: ${devices.length}');
        int count = devices.where((device) {
          final status = (device['status'] ?? '').toString().toLowerCase();
          final isActive = device['active'] == true;
          print(
            'Device status: ${device['status']} -> $status, active: ${device['active']}',
          );
          // Check both 'status' field and 'active' boolean field
          return status == 'active' ||
              status == 'فعال' ||
              status == 'online' ||
              isActive;
        }).length;
        print('Active devices count: $count');
        if (mounted) {
          setState(() {
            activeDeviceCount = count;
          });
        }
      } else {
        print('Failed to fetch devices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching devices: $e');
    }
  }

  // Fetch and count missions for level 4 (technicians)
  Future<void> fetchAndCountMissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) return;

      await SessionManager().onNetworkRequest();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse(
          'https://device-control.liara.run/api/technician/tasks?ts=$ts',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      print('Missions API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);

        if (data is List) {
          // Count only pending missions (technician_confirm == false)
          final count = data
              .where(
                (task) => task is Map && task['technician_confirm'] != true,
              )
              .length;

          print('Pending missions count: $count');
          if (mounted) {
            setState(() {
              missionCount = count;
            });
          }
        } else if (data is Map && data['error'] != null) {
          print('Missions API error: ${data['error']}');
          if (mounted) {
            setState(() {
              missionCount = 0;
            });
          }
        }
      } else {
        print('Failed to fetch missions: ${response.statusCode}');
        if (mounted) {
          setState(() {
            missionCount = 0;
          });
        }
      }
    } catch (e) {
      print('Error fetching missions: $e');
      if (mounted) {
        setState(() {
          missionCount = 0;
        });
      }
    }
  }

  // Bottom navigation state
  int selectedNavIndex = 0;
  @override
  void initState() {
    super.initState();
    // First load data from SharedPreferences (stored during login), then refresh from server
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    // Load data from SharedPreferences first (immediate display)
    await loadUserFromLocal();
    // Then refresh from server (for latest data)
    await loadUserDataFromServer();
  }

  // تابع جدید برای بارگیری دیتا از سرور
  Future<void> loadUserDataFromServer() async {
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
        return;
      }

      final tokenPrefix = token.length >= 8 ? token.substring(0, 8) : token;
      print('Home: using token prefix: $tokenPrefix');
      final ts = DateTime.now().millisecondsSinceEpoch;

      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl/load_data_user/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        print(
          'Server response - Level: ${data['level']}, Active: ${data['active']}, Modir: ${data['modir']}, Username: ${data['user']?['username']}',
        );

        // Guard: ensure server username matches the one we logged in as
        final returnedUsername = (data['user']?['username'] ?? '').toString();
        final storedUsername = (prefs.getString('username') ?? '').toString();
        if (returnedUsername.isNotEmpty &&
            storedUsername.isNotEmpty &&
            returnedUsername.toLowerCase() != storedUsername.toLowerCase()) {
          print(
            'Home: Username mismatch (stored=$storedUsername, returned=$returnedUsername). Ignoring server response.',
          );
          if (mounted) {
            setState(() => isLoading = false);
          }
          return;
        }

        await prefs.setInt('level', data['level'] ?? 3);
        await prefs.setBool('active', data['active'] ?? false);
        await prefs.setBool('modir', data['modir'] ?? false);
        await prefs.setString('username', returnedUsername);

        // Prefer HTTP(S) banner; otherwise fall back to bundled asset
        final String serverBanner = (data['banner'] ?? '').toString().trim();
        final bool isHttpUrl =
            serverBanner.startsWith('http://') ||
            serverBanner.startsWith('https://');
        final String safeBanner = isHttpUrl ? serverBanner : '';
        // Add cache-busting fragment so updated server image reflects in app
        // Fragment is not sent to server, avoids breaking signed/strict URLs
        final String displayBanner = safeBanner.isNotEmpty
            ? '$safeBanner#ts=$ts'
            : '';
        final bool bannerChanged =
            displayBanner.isNotEmpty && displayBanner != bannerUrl;

        if (mounted) {
          setState(() {
            username = returnedUsername;
            userLevel = data['level'] ?? 3;
            userActive = data['active'] ?? false;
            userModir = data['modir'] ?? false;
            bannerUrl = displayBanner;
            if (bannerChanged) {
              showBanner =
                  true; // ensure it shows again if server banner changed
            }

            // Set user role title
            final int level = data['level'] ?? 3;
            final bool isModir = data['modir'] ?? false;
            if (isModir) {
              userRoleTitle = AppLocalizations.of(
                context,
              )!.home_company_representative;
            } else if (level == 1) {
              userRoleTitle = AppLocalizations.of(context)!.home_admin;
            } else if (level == 2 || level == 4) {
              // Level 2 and 4 are both installers (technicians)
              userRoleTitle = AppLocalizations.of(context)!.home_installer;
            } else if (level == 3) {
              userRoleTitle = AppLocalizations.of(context)!.home_user;
            }

            isLoading = false;
          });
        }

        if (mounted) {
          // Fetch statistics based on user level
          if (userLevel == 4) {
            fetchAndCountMissions();
          } else if (userLevel == 3) {
            // Level 3: Only fetch active devices (no users access)
            fetchAndCountActiveDevices();
          } else {
            // Level 1 and 2: Fetch both devices and users
            fetchAndCountActiveDevices();
            fetchAndCountActiveUsers();
          }
        }
      } else if (response.statusCode == 401) {
        final preservedLanguage = prefs.getString('selectedLanguage');
        await prefs.clear();
        if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
          await prefs.setString('selectedLanguage', preservedLanguage);
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // تابع کمکی برای بارگیری از SharedPreferences (fallback)
  Future<void> loadUserFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Debug: Print stored values
      final storedLevel = prefs.getInt('level');
      final storedActive = prefs.getBool('active');
      final storedModir = prefs.getBool('modir');
      final storedUsername = prefs.getString('username');

      if (mounted) {
        setState(() {
          username = storedUsername ?? '';
          userLevel = storedLevel ?? 3;
          userActive = storedActive ?? false;
          userModir = storedModir ?? false;

          // Set user role title
          if (storedModir == true) {
            userRoleTitle = AppLocalizations.of(
              context,
            )!.home_company_representative;
          } else if (storedLevel == 1) {
            userRoleTitle = AppLocalizations.of(context)!.home_admin;
          } else if (storedLevel == 2 || storedLevel == 4) {
            // Level 2 and 4 are both installers (technicians)
            userRoleTitle = AppLocalizations.of(context)!.home_installer;
          } else if (storedLevel == 3) {
            userRoleTitle = AppLocalizations.of(context)!.home_user;
          }

          isLoading = false;
        });
      }

      // After user data is loaded, fetch statistics
      if (mounted) {
        if (userLevel == 4) {
          fetchAndCountMissions();
        } else if (userLevel == 3) {
          // Level 3: Only fetch active devices (no users access)
          fetchAndCountActiveDevices();
        } else {
          // Level 1 and 2: Fetch both devices and users
          fetchAndCountActiveDevices();
          fetchAndCountActiveUsers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // تابع برای refresh کردن دیتا (اختیاری)
  Future<void> refreshUserData() async {
    await loadUserDataFromServer();
    // Refresh statistics based on user level
    if (userLevel == 4) {
      await fetchAndCountMissions();
    } else if (userLevel == 3) {
      // Level 3: Only fetch active devices (no users access)
      await fetchAndCountActiveDevices();
    } else {
      // Level 1 and 2: Fetch both devices and users
      await fetchAndCountActiveDevices();
      await fetchAndCountActiveUsers();
    }
  }

  Future<void> logout() async {
    final confirmed = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  ctx,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.home_logout,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              AppLocalizations.of(context)!.home_logout_confirm,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                AppLocalizations.of(context)!.home_no,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
              child: Text(
                AppLocalizations.of(context)!.home_yes,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      // End session using session manager
      await SessionManager().endSession(clearBiometric: true);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildNavigationCard({
    required Widget icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ui = UiScale(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(
          ui.scale(base: 12, min: 10, max: 14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            ui.scale(base: 12, min: 10, max: 14),
          ),
          child: Padding(
            padding: EdgeInsets.all(ui.scale(base: 16, min: 12, max: 20)),
            child: Row(
              children: [
                Container(
                  width: ui.scale(base: 40, min: 32, max: 48),
                  height: ui.scale(base: 40, min: 32, max: 48),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ui.scale(base: 8, min: 6, max: 10),
                    ),
                  ),
                  child: Center(child: icon),
                ),
                SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: ui.scale(base: 16, min: 14, max: 18),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: ui.scale(base: 2, min: 2, max: 4)),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: ui.scale(base: 12, min: 10, max: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[500]
                      : Colors.grey[400],
                  size: ui.scale(base: 16, min: 14, max: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    if (mounted) {
      setState(() {
        selectedNavIndex = index;
      });
    }

    // Handle navigation based on selected index and user level
    if (userLevel == 4) {
      // Technician navigation: Home (0), Profile (1), Reports (2), Missions (3)
      switch (index) {
        case 0: // Home
          if (ModalRoute.of(context)?.settings.name != '/home') {
            Navigator.pushReplacementNamed(context, '/home');
          }
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Reports
          if (ModalRoute.of(context)?.settings.name != '/technician-reports') {
            Navigator.pushReplacementNamed(context, '/technician-reports');
          }
          break;
        case 3: // Missions
          if (ModalRoute.of(context)?.settings.name != '/technician-tasks') {
            Navigator.pushReplacementNamed(context, '/technician-tasks');
          }
          break;
      }
    } else if (userLevel == 2) {
      // Service provider navigation: Home (0), Profile (1), Services (2)
      switch (index) {
        case 0: // Home
          if (ModalRoute.of(context)?.settings.name != '/home') {
            Navigator.pushReplacementNamed(context, '/home');
          }
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Services
          if (ModalRoute.of(context)?.settings.name !=
              '/service-provider-services') {
            Navigator.pushReplacementNamed(
              context,
              '/service-provider-services',
            );
          }
          break;
      }
    } else {
      // Original navigation for other user levels
      switch (index) {
        case 0: // Home
          if (ModalRoute.of(context)?.settings.name != '/home') {
            Navigator.pushReplacementNamed(context, '/home');
          }
          break;
        case 1: // Devices
          if (ModalRoute.of(context)?.settings.name != '/devices') {
            Navigator.pushReplacementNamed(context, '/devices');
          }
          break;
        case 2: // Reports
          if (userLevel == 3) {
            if (ModalRoute.of(context)?.settings.name != '/reports') {
              Navigator.pushReplacementNamed(context, '/reports');
            }
          } else {
            if (ModalRoute.of(context)?.settings.name != '/commands') {
              Navigator.pushReplacementNamed(context, '/commands');
            }
          }
          break;
        case 3: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 4: // Users
          if (ModalRoute.of(context)?.settings.name != '/users') {
            Navigator.pushReplacementNamed(context, '/users');
          }
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final ui = UiScale(context);

    // Consistent, clamped sizing across phones so UI keeps the same shape
    final logoHeight = (screenHeight * 0.25).clamp(180.0, 260.0);
    final svgHeight = (logoHeight * 0.9).clamp(150.0, 240.0);
    final svgWidth = (screenWidth * 0.9).clamp(260.0, 420.0);
    final double horizontalPadding = (screenWidth * 0.05).clamp(12.0, 24.0);

    if (userModir) {
      userRoleTitle = AppLocalizations.of(context)!.home_company_representative;
    } else if (userLevel == 1) {
      userRoleTitle = AppLocalizations.of(context)!.home_admin;
    } else if (userLevel == 2 || userLevel == 4) {
      // Level 2 and 4 are both installers (technicians)
      userRoleTitle = AppLocalizations.of(context)!.home_installer;
    } else if (userLevel == 3) {
      userRoleTitle = AppLocalizations.of(context)!.home_user;
    }
    if (isLoading) {
      return Consumer<SettingsProvider>(
        builder: (context, value, child) => PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            // If drawer is open, close it instead of exiting
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              _scaffoldKey.currentState?.closeDrawer();
              return;
            }
            final now = DateTime.now();
            if (_lastBackPressedAt == null ||
                now.difference(_lastBackPressedAt!) >
                    const Duration(seconds: 2)) {
              _lastBackPressedAt = now;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.click_again_to_exit,
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Container(
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Left side - Icons
                        Row(
                          children: [
                            Builder(
                              builder: (context) => IconButton(
                                icon: Icon(
                                  Icons.menu,
                                  color: Theme.of(
                                    context,
                                  ).appBarTheme.iconTheme?.color,
                                ),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.notifications,
                                color: Theme.of(
                                  context,
                                ).appBarTheme.iconTheme?.color,
                              ),
                              onPressed: () {},
                            ),
                          ],
                        ),

                        // Center - Text
                        Expanded(
                          child: Center(
                            child: LoadingAnimationWidget.staggeredDotsWave(
                              color: AppColors.lapisLazuli,
                              size: 20,
                            ),
                          ),
                        ),

                        // Right side - Logo
                        Image.asset(
                          'assets/logouzita.png',
                          height: screenHeight * 0.08,
                          width: screenHeight * 0.08,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            key: _scaffoldKey,
            drawer: SharedAppDrawer(
              username: username,
              userRoleTitle: userRoleTitle,
              userModir: userModir,
              userLevel: userLevel,
              refreshUserData: refreshUserData,
              logout: () async {
                final prefs = await SharedPreferences.getInstance();
                // Preserve user preferences
                final saved = prefs.getString('saved_username');
                final preservedLanguage = prefs.getString('selectedLanguage');
                final preservedDarkMode = prefs.getBool('darkModeEnabled');
                final preservedTextSize = prefs.getDouble('textSize');
                final preservedNotifications = prefs.getBool(
                  'notificationsEnabled',
                );

                await prefs.clear();

                // Restore preserved settings
                if (saved != null && saved.isNotEmpty) {
                  await prefs.setString('saved_username', saved);
                }
                if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
                  await prefs.setString('selectedLanguage', preservedLanguage);
                }
                if (preservedDarkMode != null) {
                  await prefs.setBool('darkModeEnabled', preservedDarkMode);
                }
                if (preservedTextSize != null) {
                  await prefs.setDouble('textSize', preservedTextSize);
                }
                if (preservedNotifications != null) {
                  await prefs.setBool(
                    'notificationsEnabled',
                    preservedNotifications,
                  );
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              userActive: true,
            ),
            body: Center(
              child: SharedLoading(
                title: AppLocalizations.of(context)!.home_loading,
              ),
            ),
            bottomNavigationBar: SharedBottomNavigation(
              selectedIndex: selectedNavIndex,
              userLevel: userLevel,
              onItemTapped: _onNavItemTapped,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If drawer is open, close it instead of exiting
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.click_again_to_exit),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            color: theme.appBarTheme.backgroundColor,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Left side - Icons
                    Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: theme.appBarTheme.iconTheme?.color,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.notifications,
                            color: theme.appBarTheme.iconTheme?.color,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),

                    // Center - Text
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              userRoleTitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right side - Logo
                    Image.asset(
                      'assets/logouzita.png',
                      height: screenHeight * 0.08,
                      width: screenHeight * 0.08,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        drawer: SharedAppDrawer(
          username: username,
          userRoleTitle: userRoleTitle,
          userModir: userModir,
          userLevel: userLevel,
          refreshUserData: refreshUserData,
          logout: () async {
            final prefs = await SharedPreferences.getInstance();
            // Preserve user preferences
            final saved = prefs.getString('saved_username');
            final preservedLanguage = prefs.getString('selectedLanguage');
            final preservedDarkMode = prefs.getBool('darkModeEnabled');
            final preservedTextSize = prefs.getDouble('textSize');
            final preservedNotifications = prefs.getBool(
              'notificationsEnabled',
            );

            await prefs.clear();

            // Restore preserved settings
            if (saved != null && saved.isNotEmpty) {
              await prefs.setString('saved_username', saved);
            }
            if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
              await prefs.setString('selectedLanguage', preservedLanguage);
            }
            if (preservedDarkMode != null) {
              await prefs.setBool('darkModeEnabled', preservedDarkMode);
            }
            if (preservedTextSize != null) {
              await prefs.setDouble('textSize', preservedTextSize);
            }
            if (preservedNotifications != null) {
              await prefs.setBool(
                'notificationsEnabled',
                preservedNotifications,
              );
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
          },
          userActive: userActive,
        ),
        body: userActive
            ? Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: refreshUserData,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            10.0,
                            horizontalPadding,
                            20.0 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            children: [
                              Column(
                                children: [
                                  Stack(
                                    children: [
                                      // Logo section with extra space to accommodate overlay cards
                                      SizedBox(
                                        height: logoHeight + 28,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned(
                                              top: -logoHeight * 0.2,
                                              child: Image.asset(
                                                'assets/biokaveh.png',
                                                height: svgHeight,
                                                width: svgWidth,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Statistics Cards with Positioning
                                      Positioned(
                                        top: logoHeight * 0.54,
                                        left: 0,
                                        right: 0,
                                        child: Column(
                                          children: [
                                            // For level 4: Show missions count (single card)
                                            // For other levels: Show devices and users count (two cards)
                                            if (userLevel == 4)
                                              Container(
                                                width: double.infinity,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).cardTheme.color,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      spreadRadius: 1,
                                                      blurRadius: 5,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      missionCount.toString(),
                                                      style: TextStyle(
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .lapisLazuli,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: ui.scale(
                                                        base: 6,
                                                        min: 4,
                                                        max: 10,
                                                      ),
                                                    ),
                                                    Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      )!.home_pending_missions,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 17,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              // For level 3: Show only Active Devices
                                              // For level 1 and 2: Show both Active Devices and Active Users
                                              userLevel == 3
                                                  ? Container(
                                                      width: double.infinity,
                                                      height: 100,
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(
                                                          context,
                                                        ).cardTheme.color,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.grey
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                            spreadRadius: 1,
                                                            blurRadius: 5,
                                                            offset: Offset(
                                                              0,
                                                              2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            activeDeviceCount
                                                                .toString(),
                                                            style: TextStyle(
                                                              fontSize: 24,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .lapisLazuli,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            height: ui.scale(
                                                              base: 6,
                                                              min: 4,
                                                              max: 10,
                                                            ),
                                                          ),
                                                          Text(
                                                            AppLocalizations.of(
                                                              context,
                                                            )!.home_active_devices,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 17,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            height: 100,
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(
                                                                context,
                                                              ).cardTheme.color,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.grey
                                                                      .withValues(
                                                                        alpha: 0.1,
                                                                      ),
                                                                  spreadRadius: 1,
                                                                  blurRadius: 5,
                                                                  offset: Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  activeDeviceCount
                                                                      .toString(),
                                                                  style: TextStyle(
                                                                    fontSize: 24,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: AppColors
                                                                        .lapisLazuli,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: ui.scale(
                                                                    base: 6,
                                                                    min: 4,
                                                                    max: 10,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  AppLocalizations.of(
                                                                    context,
                                                                  )!.home_active_devices,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize: 17,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 20),
                                                        Expanded(
                                                          child: Container(
                                                            height: 100,
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(
                                                                context,
                                                              ).cardTheme.color,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.grey
                                                                      .withValues(
                                                                        alpha: 0.1,
                                                                      ),
                                                                  spreadRadius: 1,
                                                                  blurRadius: 5,
                                                                  offset: Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Text(
                                                                  onlineUserCount
                                                                      .toString(),
                                                                  style: TextStyle(
                                                                    fontSize: 24,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: AppColors
                                                                        .lapisLazuli,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: ui.scale(
                                                                    base: 6,
                                                                    min: 4,
                                                                    max: 10,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  AppLocalizations.of(
                                                                    context,
                                                                  )!.home_active_users,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.copyWith(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize: 17,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            // const SizedBox(height: 20),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // SizedBox(height: 20),

                                  // Navigation Cards
                                  Column(
                                    children: [
                                      // Device list - hidden for level 4
                                      if (userLevel != 4)
                                        _buildNavigationCard(
                                          icon: SvgPicture.asset(
                                            'assets/icons/device.svg',
                                            width: 24,
                                            height: 24,
                                          ),
                                          iconColor: Colors.transparent,
                                          title: AppLocalizations.of(
                                            context,
                                          )!.home_device_list,
                                          subtitle: AppLocalizations.of(
                                            context,
                                          )!.home_device_list_description,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DeviceListScreen(),
                                            ),
                                          ),
                                        ),
                                      if (userLevel != 4) SizedBox(height: 12),
                                      // User list - hidden for level 3 and 4
                                      if (userLevel != 3 && userLevel != 4)
                                        _buildNavigationCard(
                                          icon: SvgPicture.asset(
                                            'assets/icons/users.svg',
                                            width: 24,
                                            height: 24,
                                          ),
                                          iconColor: Colors.transparent,
                                          title: AppLocalizations.of(
                                            context,
                                          )!.home_user_list,
                                          subtitle: AppLocalizations.of(
                                            context,
                                          )!.home_user_list_description,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => UserListScreen(),
                                            ),
                                          ),
                                        ),
                                      if (userLevel != 3 && userLevel != 4)
                                        SizedBox(height: 12),
                                      // Reports - for level 4, show technician reports
                                      _buildNavigationCard(
                                        icon: SvgPicture.asset(
                                          'assets/icons/report.svg',
                                          width: 24,
                                          height: 24,
                                        ),
                                        iconColor: Colors.transparent,
                                        title: AppLocalizations.of(
                                          context,
                                        )!.home_reports,
                                        subtitle: AppLocalizations.of(
                                          context,
                                        )!.home_reports_description,
                                        onTap: () {
                                          if (userLevel == 4) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    TechnicianReportsScreen(),
                                              ),
                                            );
                                          } else {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    CommandListScreen(),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      _buildNavigationCard(
                                        icon: SvgPicture.asset(
                                          'assets/icons/setting.svg',
                                          width: 24,
                                          height: 24,
                                        ),
                                        iconColor: Colors.transparent,
                                        title: AppLocalizations.of(
                                          context,
                                        )!.home_settings,
                                        subtitle: AppLocalizations.of(
                                          context,
                                        )!.home_settings_description,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SettingsScreen(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20),
                                      // Advertisement Banner (responsive, no crop)
                                      if (showBanner)
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                width: double.infinity,
                                                // height:
                                                //     180, // fixed height for consistent look across mobiles
                                                color: Theme.of(
                                                  context,
                                                ).cardTheme.color,
                                                child: bannerUrl.isNotEmpty
                                                    ? Image.network(
                                                        bannerUrl,
                                                        fit: BoxFit.contain,
                                                        alignment:
                                                            Alignment.center,
                                                        headers: const {
                                                          'Cache-Control':
                                                              'no-cache, no-store, must-revalidate',
                                                          'Pragma': 'no-cache',
                                                        },
                                                      )
                                                    : Image.asset(
                                                        'assets/banner.jpg',
                                                        fit: BoxFit.contain,
                                                        alignment:
                                                            Alignment.center,
                                                      ),
                                              ),
                                            ),
                                            // Close button
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: GestureDetector(
                                                onTap: () {
                                                  if (mounted) {
                                                    setState(() {
                                                      showBanner = false;
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar
                  // Removed in-body bottom nav; now using Scaffold.bottomNavigationBar
                ],
              )
            : _buildInactiveState(),
        bottomNavigationBar: SharedBottomNavigation(
          selectedIndex: selectedNavIndex,
          userLevel: userLevel,
          onItemTapped: _onNavItemTapped,
        ),
      ),
    );
  }

  // Inactive state for level 3 users
  Widget _buildInactiveState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.hourglass_empty_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),

            SizedBox(height: 24),

            // Title
            Text(
              AppLocalizations.of(context)!.home_account_pending,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),

            SizedBox(height: 12),

            // Description Card
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.lapisLazuli,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.home_account_pending_description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Contact Admin Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.home_contact_admin,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.home_contact_admin_button,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lapisLazuli,
                  side: BorderSide(color: AppColors.lapisLazuli, width: 2),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
