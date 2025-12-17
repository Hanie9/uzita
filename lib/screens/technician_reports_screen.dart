import 'package:flutter/material.dart';
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

class TechnicianReportsScreen extends StatefulWidget {
  const TechnicianReportsScreen({super.key});

  @override
  State<TechnicianReportsScreen> createState() =>
      _TechnicianReportsScreenState();
}

class _TechnicianReportsScreenState extends State<TechnicianReportsScreen> {
  List tasks = [];
  bool isLoading = true;
  int selectedNavIndex = 2; // Reports tab index for level 4 users
  int userLevel = 4;
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isModir = prefs.getBool('modir') ?? false;
    setState(() {
      userLevel = prefs.getInt('level') ?? 4;
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      if (isModir) {
        userRoleTitle = AppLocalizations.of(
          context,
        )!.pro_company_representative;
      } else if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (userLevel == 2 || userLevel == 4) {
        userRoleTitle = AppLocalizations.of(context)!.pro_installer;
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
        Uri.parse(
          'https://device-control.liara.run/api/technician/reports?ts=$ts',
        ),
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
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
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
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
      body: Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
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
                        bottom: MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lapisLazuli.withValues(alpha: 0.1),
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
                    left: kSpacing,
                    right: kSpacing,
                    top: kSpacing,
                    bottom:
                        kSpacing + MediaQuery.of(context).padding.bottom + 20,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final title = task['title'] ?? '---';
                    final price = task['price']?.toString() ?? '0';
                    final organName = task['organ_name'] ?? '---';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/technician-task-detail',
                          arguments: task,
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
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
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]!
                                : AppColors.lapisLazuli.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            textDirection: Directionality.of(context),
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: Directionality.of(context),
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: Directionality.of(context),
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          size: 14,
                                          color: AppColors.maroon,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '$price ${localizations.sls_tooman}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.maroon,
                                            ),
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      textDirection: Directionality.of(context),
                                      children: [
                                        Icon(
                                          Icons.business,
                                          size: 14,
                                          color: AppColors.iranianGray,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            organName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.iranianGray,
                                            ),
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_left,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.5),
                                textDirection:
                                    Directionality.of(context) ==
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
