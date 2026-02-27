import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'dart:convert';
import '../services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:shamsi_date/shamsi_date.dart';

class TechnicianReportsScreen extends StatefulWidget {
  const TechnicianReportsScreen({super.key});

  @override
  State<TechnicianReportsScreen> createState() =>
      _TechnicianReportsScreenState();
}

class _TechnicianReportsScreenState extends State<TechnicianReportsScreen> {
  List tasks = [];
  bool isLoading = true;
  int selectedNavIndex = 2; // Reports tab index for technician users
  int userLevel = 2;
  String organType = '';
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
    final bool isModir = prefs.getBool('modir') ?? false;
    setState(() {
      userLevel = prefs.getInt('level') ?? 2;
      organType = (prefs.getString('organ_type') ?? '').toLowerCase();
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      final int logicalLevel = getLogicalUserLevel(userLevel);
      if (isModir && logicalLevel == 1 && organType == 'technician') {
        userRoleTitle = AppLocalizations.of(
          context,
        )!.pro_company_representative;
      } else if (logicalLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (logicalLevel == 2 && organType == 'technician') {
        userRoleTitle = AppLocalizations.of(context)!.pro_installer;
      } else if (logicalLevel == 3) {
        userRoleTitle = AppLocalizations.of(context)!.home_driver;
      } else {
        userRoleTitle = AppLocalizations.of(context)!.pro_user;
      }
    });
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      await SessionManager().onNetworkRequest();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl5/technician/reports?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is Map && data['error'] != null) {
          setState(() {
            tasks = [];
            isLoading = false;
          });
        } else if (data is Map && data['results'] != null) {
          // Handle paginated response
          final results = data['results'];
          if (results is List) {
            setState(() {
              tasks = results;
              isLoading = false;
            });
          } else {
            setState(() {
              tasks = [];
              isLoading = false;
            });
          }
        } else {
          setState(() {
            tasks = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          tasks = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        tasks = [];
      });
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    // Technician / service-lead navigation from reports screen
    if (userLevel == 1 && organType == 'technician') {
      // Service team lead: Home (0), Profile (1), Reports (2), Missions (3), Users (4)
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Reports - already here
          break;
        case 3: // Missions (organization tasks)
          Navigator.pushReplacementNamed(context, '/technician-organ-tasks');
          break;
        case 4: // Users
          Navigator.pushReplacementNamed(context, '/users');
          break;
      }
    } else if (userLevel == 1) {
      // Level 1 non-technician: Devices (1), Reports (2), Home (0), Users (4), Profile (3)
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/devices');
          break;
        case 2: // Reports - already here
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 4:
          Navigator.pushReplacementNamed(context, '/users');
          break;
      }
    } else {
      // Regular technician: Home (0), Profile (1), Reports (2), Missions (3)
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Reports - already here
          break;
        case 3: // Missions
          Navigator.pushReplacementNamed(context, '/technician-tasks');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
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
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.scale(base: 16, min: 12, max: 20),
                ),
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
                            onPressed: () => Scaffold.of(context).openDrawer(),
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
                        child: Text(
                          localizations.nav_reports,
                          style: Theme.of(context).appBarTheme.titleTextStyle,
                        ),
                      ),
                    ),

                    // Right side - Logo
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
              ),
            ),
          ),
        ),
        body: !userActive
            ? _buildInactiveState()
            : Directionality(
                textDirection:
                    Provider.of<SettingsProvider>(
                          context,
                          listen: false,
                        ).selectedLanguage ==
                        'en'
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: Column(
                  children: [
                    // Blue header box
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(
                        horizontal: ui.scale(base: 16, min: 12, max: 20),
                        vertical: ui.scale(base: 8, min: 6, max: 12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: ui.scale(base: 16, min: 12, max: 20),
                        vertical: ui.scale(base: 12, min: 8, max: 16),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.lapisLazuli,
                            AppColors.lapisLazuli.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          ui.scale(base: 12, min: 10, max: 14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: ui.scale(base: 40, min: 32, max: 48),
                            height: ui.scale(base: 40, min: 32, max: 48),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.description,
                              color: Colors.white,
                              size: ui.scale(base: 20, min: 16, max: 24),
                            ),
                          ),
                          SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      localizations.nav_reports,
                                      style: TextStyle(
                                        fontSize: ui.scale(
                                          base: 18,
                                          min: 16,
                                          max: 20,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    isLoading
                                        ? Row(
                                            children: [
                                              SizedBox(
                                                width: ui.scale(
                                                  base: 14,
                                                  min: 12,
                                                  max: 16,
                                                ),
                                                height: ui.scale(
                                                  base: 14,
                                                  min: 12,
                                                  max: 16,
                                                ),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            '${tasks.length} ${localizations.nav_report}',
                                            style: TextStyle(
                                              fontSize: ui.scale(
                                                base: 13,
                                                min: 12,
                                                max: 15,
                                              ),
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
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
                    // Content
                    Expanded(
                      child: isLoading
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      top: 20,
                                      bottom: MediaQuery.of(
                                        context,
                                      ).padding.bottom,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lapisLazuli.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.lapisLazuli,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    localizations.sls_loading,
                                    style: TextStyle(
                                      color: AppColors.lapisLazuli,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : tasks.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: fetchTasks,
                              color: AppColors.lapisLazuli,
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  left: ui.scale(base: 16, min: 12, max: 20),
                                  right: ui.scale(base: 16, min: 12, max: 20),
                                  top: ui.scale(base: 16, min: 12, max: 20),
                                  bottom:
                                      ui.scale(base: 16, min: 12, max: 20) +
                                      MediaQuery.of(context).padding.bottom +
                                      20,
                                ),
                                itemCount: tasks.length,
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final title =
                                      task['title']?.toString() ?? '---';
                                  final address =
                                      task['address']?.toString() ?? '---';
                                  final status =
                                      task['status']?.toString() ?? 'open';
                                  final createdAt =
                                      task['created_at']?.toString() ?? '';
                                  // Get price - could be 'hazine', 'sayer_hazine', or 'price'
                                  final dynamic priceValue =
                                      task['hazine'] ??
                                      task['sayer_hazine'] ??
                                      task['price'];
                                  final String price = priceValue == null
                                      ? '---'
                                      : priceValue.toString();

                                  final bool isTechnicianOrgManager =
                                      userLevel == 1 &&
                                      organType == 'technician';
                                  final bool isNormalTechnician =
                                      userLevel == 2;
                                  final bool allowTap =
                                      !isNormalTechnician &&
                                      !isTechnicianOrgManager;

                                  return GestureDetector(
                                    onTap: allowTap
                                        ? () {
                                            Navigator.pushNamed(
                                              context,
                                              '/technician-task-detail',
                                              arguments: task,
                                            );
                                          }
                                        : null,
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).cardTheme.color,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.black.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : AppColors.lapisLazuli
                                                      .withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[700]!
                                              : AppColors.lapisLazuli
                                                    .withValues(alpha: 0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Row(
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                          children: [
                                            // Status badge (like service list)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  status,
                                                ).withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _getStatusColor(
                                                    status,
                                                  ).withValues(alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                _getStatusText(
                                                  status,
                                                  localizations,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getStatusColor(
                                                    status,
                                                  ),
                                                ),
                                                textDirection:
                                                    Directionality.of(context),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Title
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    textDirection:
                                                        Directionality.of(
                                                          context,
                                                        ),
                                                    children: [
                                                      Icon(
                                                        Icons.title,
                                                        size: 14,
                                                        color: AppColors
                                                            .lapisLazuli,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          title,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.color,
                                                          ),
                                                          textDirection:
                                                              Directionality.of(
                                                                context,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Price
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    textDirection:
                                                        Directionality.of(
                                                          context,
                                                        ),
                                                    children: [
                                                      Icon(
                                                        Icons.attach_money,
                                                        size: 14,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          price == '---'
                                                              ? '---'
                                                              : '$price ${localizations.sls_tooman}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .iranianGray,
                                                          ),
                                                          textDirection:
                                                              Directionality.of(
                                                                context,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Address
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    textDirection:
                                                        Directionality.of(
                                                          context,
                                                        ),
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          address,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppColors
                                                                .iranianGray,
                                                          ),
                                                          textDirection:
                                                              Directionality.of(
                                                                context,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Date
                                                  if (createdAt.isNotEmpty)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      textDirection:
                                                          Directionality.of(
                                                            context,
                                                          ),
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 14,
                                                          color: AppColors
                                                              .iranianGray,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            _formatDate(
                                                              createdAt,
                                                            ),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors
                                                                  .iranianGray,
                                                            ),
                                                            textDirection:
                                                                Directionality.of(
                                                                  context,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Hide arrow (>) for normal technician (level 2)
                                            // and for technician organization manager (level 1, organ_type=technician)
                                            if (!isNormalTechnician &&
                                                !isTechnicianOrgManager)
                                              Icon(
                                                Icons.chevron_left,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withValues(alpha: 0.5),
                                                textDirection:
                                                    Directionality.of(
                                                          context,
                                                        ) ==
                                                        TextDirection.rtl
                                                    ? TextDirection.ltr
                                                    : TextDirection.rtl,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
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
        ),
        bottomNavigationBar: SharedBottomNavigation(
          selectedIndex: selectedNavIndex,
          userLevel: userLevel,
          onItemTapped: _onNavItemTapped,
          organType: organType,
        ),
      ),
    );
  }

  // Inactive state (for users whose account is not active)
  Widget _buildInactiveState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.support_agent_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              AppLocalizations.of(context)!.tls_waiting_for_activation,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              AppLocalizations.of(
                context,
              )!.tls_waiting_for_activation_description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Contact Admin Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.tls_contact_admin,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.tls_contact_admin_button,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lapisLazuli,
                  side: const BorderSide(
                    color: AppColors.lapisLazuli,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  String _formatDate(String dateString) {
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

  String _getStatusText(String status, AppLocalizations localizations) {
    switch (status) {
      case 'open':
        return localizations.sps_status_open;
      case 'assigned':
        return localizations.sps_status_assigned;
      case 'confirm':
        return localizations.sps_status_confirm;
      case 'done':
        return localizations.sps_status_done;
      case 'canceled':
        return localizations.sps_status_canceled;
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      case 'confirm':
        return Colors.blue;
      default:
        return Colors.orange;
    }
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
                Icons.check_circle_outline,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              localizations.tech_no_completed_tasks,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              localizations.tech_no_completed_tasks_description,
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
