import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/screens/login_screen.dart';

class DriverPublicLoadsScreen extends StatefulWidget {
  const DriverPublicLoadsScreen({super.key});

  @override
  State<DriverPublicLoadsScreen> createState() =>
      _DriverPublicLoadsScreenState();
}

class _DriverPublicLoadsScreenState extends State<DriverPublicLoadsScreen> {
  List<dynamic> loads = [];
  bool isLoading = true;
  int selectedNavIndex = 3; // Public loads tab index for level 5 users
  int userLevel = 5;
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 5;
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (userLevel == 5) {
        userRoleTitle = AppLocalizations.of(context)!.home_driver;
      } else {
        userRoleTitle = AppLocalizations.of(context)!.pro_user;
      }
    });
    _fetchLoads();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // Reports
        Navigator.pushReplacementNamed(context, '/driver-reports');
        break;
      case 2: // Missions
        Navigator.pushReplacementNamed(context, '/driver-missions');
        break;
      case 3: // Public loads - already here
        break;
      case 4: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Future<void> _fetchLoads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse(
          'https://device-control.liara.run/api/transport/listrequest?ts=$ts',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);

        List<dynamic> all = [];
        if (data is List) {
          all = data;
        } else if (data is Map && data['results'] is List) {
          all = data['results'] as List<dynamic>;
        }

        // Public loads: status = open and driver == null
        final filtered = all.where((item) {
          if (item is! Map) return false;
          final status = (item['status'] ?? '').toString();
          final driver = item['driver'];
          return status == 'open' && driver == null;
        }).toList();

        setState(() {
          loads = filtered;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  String _formatDate(BuildContext context, String dateString) {
    try {
      final date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        final j = Jalali.fromDateTime(date);
        return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return dateString;
    }
  }

  String _buildPiecesSummary(List<dynamic> pieces) {
    if (pieces.isEmpty) return '---';
    final safePieces = pieces.map((e) => e.toString()).toList();
    if (safePieces.length == 1) return safePieces.first;
    if (safePieces.length == 2) return '${safePieces[0]} و ${safePieces[1]}';
    return '${safePieces[0]} و ${safePieces[1]} و ...';
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final localizations = AppLocalizations.of(context)!;

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
              content: Text(localizations.click_again_to_exit),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.scale(base: 16, min: 12, max: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: Icon(
                            Icons.menu,
                            color: Theme.of(context).appBarTheme.iconTheme?.color,
                          ),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.notifications,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        localizations.nav_public_loads,
                        style:
                            Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Image.asset(
                        'assets/logouzita.png',
                        height: ui.scale(
                          base: screenHeight * 0.08,
                          min: 28,
                          max: 56,
                        ),
                        width: ui.scale(
                          base: screenHeight * 0.08,
                          min: 28,
                          max: 56,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection:
            Provider.of<SettingsProvider>(context, listen: false)
                        .selectedLanguage ==
                    'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.lapisLazuli,
                  ),
                  strokeWidth: 3,
                ),
              )
            : loads.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchLoads,
                    color: AppColors.lapisLazuli,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: kSpacing,
                        right: kSpacing,
                        top: kSpacing,
                        bottom: kSpacing +
                            MediaQuery.of(context).padding.bottom +
                            20,
                      ),
                      itemCount: loads.length,
                      itemBuilder: (context, index) {
                        final load = loads[index] as Map;
                        final List<dynamic> pieces =
                            (load['pieces'] as List?) ?? [];
                        final createdAt =
                            (load['created_at'] ?? '').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.black.withValues(alpha: 0.2)
                                        : AppColors.lapisLazuli.withValues(
                                            alpha: 0.06,
                                          ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[700]!
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.08,
                                    ),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.lapisLazuli,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _buildPiecesSummary(pieces),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: AppColors.iranianGray,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              createdAt.isNotEmpty
                                                  ? _formatDate(
                                                      context,
                                                      createdAt,
                                                    )
                                                  : '---',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.iranianGray,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
      drawer: SharedAppDrawer(
        username: username,
        userRoleTitle: userRoleTitle,
        userModir: false,
        userLevel: userLevel,
        refreshUserData: _loadUserData,
        userActive: userActive,
        logout: () async {
          final prefs = await SharedPreferences.getInstance();
          // Preserve user preferences
          final saved = prefs.getString('saved_username');
          final preservedLanguage = prefs.getString('selectedLanguage');
          final preservedDarkMode = prefs.getBool('darkModeEnabled');
          final preservedTextSize = prefs.getDouble('textSize');
          final preservedNotifications = prefs.getBool('notificationsEnabled');

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
            await prefs.setBool('notificationsEnabled', preservedNotifications);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        },
      ),
      bottomNavigationBar: SharedBottomNavigation(
        selectedIndex: selectedNavIndex,
        userLevel: userLevel,
        onItemTapped: _onNavItemTapped,
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(kSpacing),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.lapisLazuli.withValues(alpha: 0.15),
                    AppColors.lapisLazuli.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              localizations.public_loads_no_loads,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              localizations.public_loads_no_loads_description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



