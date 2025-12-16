import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/user_allowed_devices_screen.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/ui_scale.dart';

class UserDetailScreen extends StatefulWidget {
  final Map user;
  const UserDetailScreen(this.user, {super.key});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool loading = false;
  late bool isUserActive;
  int currentUserLevel = 3;
  bool currentUserModir = false;

  @override
  void initState() {
    super.initState();
    // Check both possible data structure paths
    isUserActive =
        (widget.user['user']?['active'] ?? widget.user['active']) == true;
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserLevel = prefs.getInt('level') ?? 3;
      currentUserModir = prefs.getBool('modir') ?? false;
    });
  }

  bool _canManageUser() {
    final targetUserLevel =
        widget.user['user']?['level'] ?? widget.user['level'] ?? 3;

    // Company representative (modir=true) can manage everyone
    if (currentUserModir) {
      return true;
    }

    // Level 1 users without modir cannot manage other level 1 users
    if (currentUserLevel == 1 && targetUserLevel == 1) {
      return false;
    }

    // Level 1 users can manage level 2 and 3 users
    if (currentUserLevel == 1 && targetUserLevel > 1) {
      return true;
    }

    // Level 2 and 3 users cannot manage anyone
    return false;
  }

  Future<void> toggleActive() async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final username = widget.user['user']['username'];
      final currentStatus = isUserActive;

      final response = await http.post(
        Uri.parse('$baseUrl/activateuser/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'username': username}),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        // Update the local user data
        setState(() {
          isUserActive = !currentStatus;
          // Update both possible data structure paths
          if (widget.user['user'] != null) {
            widget.user['user']['active'] = !currentStatus;
          }
          widget.user['active'] = !currentStatus;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus
                  ? AppLocalizations.of(context)!.uds_inactive_success
                  : AppLocalizations.of(context)!.uds_active_success,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.lapisLazuli,
            duration: Duration(seconds: 3),
          ),
        );

        // Return true to indicate changes were made
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error'] ??
                  AppLocalizations.of(context)!.uds_error_changing_status,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.uds_error_connecting,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => loading = false);
  }

  Future<void> deleteUser() async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final username = widget.user['user']['username'];

      final response = await http.post(
        Uri.parse('$baseUrl/deleteuser/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'username': username}),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.uds_delete_user_success,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error'] ?? AppLocalizations.of(context)!.uds_delete_user,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.uds_error_connecting,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => loading = false);
  }

  Future<void> editUserLevel(int newLevel) async {
    setState(() => loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final username = widget.user['user']['username'];

      final response = await http.put(
        Uri.parse('$baseUrl/editlevel/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'username': username, 'level': newLevel}),
      );

      if (response.statusCode == 200) {
        // Update the local user data
        setState(() {
          widget.user['user']['level'] = newLevel;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.uds_change_level_success,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error'] ??
                  AppLocalizations.of(context)!.uds_change_level_error,
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.uds_error_connecting,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() => loading = false);
  }

  void showLevelSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              UiScale(context).scale(base: 16, min: 12, max: 20),
            ),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: UiScale(context).scale(base: 16, min: 12, max: 20),
            vertical: UiScale(context).scale(base: 24, min: 16, max: 28),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: UiScale(context).scale(base: 8, min: 6, max: 12),
            vertical: UiScale(context).scale(base: 8, min: 6, max: 12),
          ),
          title: Directionality(
            textDirection: Localizations.localeOf(context).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.lapisLazuli,
                  size: UiScale(context).scale(base: 24, min: 20, max: 28),
                ),
                SizedBox(
                  width: UiScale(context).scale(base: 8, min: 6, max: 10),
                ),
                Text(
                  AppLocalizations.of(context)!.uds_change_level_title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          content: Directionality(
            textDirection: Localizations.localeOf(context).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      UiScale(context).scale(base: 12, min: 10, max: 16),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        UiScale(context).scale(base: 8, min: 6, max: 12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.lapisLazuli,
                          size: UiScale(
                            context,
                          ).scale(base: 20, min: 18, max: 24),
                        ),
                        SizedBox(
                          width: UiScale(
                            context,
                          ).scale(base: 8, min: 6, max: 12),
                        ),
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context)!.uds_current_level} ${_getLevelText(widget.user['level'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.titleMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: UiScale(context).scale(base: 16, min: 12, max: 20),
                  ),
                  Text(
                    AppLocalizations.of(context)!.uds_select_new_level,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  SizedBox(
                    height: UiScale(context).scale(base: 16, min: 12, max: 20),
                  ),
                  ...List.generate(3, (index) {
                    int level = index + 1;
                    String levelTitle = '';
                    String levelDescription = '';
                    Color levelColor = AppColors.lapisLazuli;

                    switch (level) {
                      case 1:
                        levelTitle = AppLocalizations.of(context)!.uds_level_1;
                        levelDescription = AppLocalizations.of(
                          context,
                        )!.uds_level_1_description;
                        levelColor = Colors.red; // destructive
                        break;
                      case 2:
                        levelTitle = AppLocalizations.of(context)!.uds_level_2;
                        levelDescription = AppLocalizations.of(
                          context,
                        )!.uds_level_2_description;
                        levelColor = AppColors.lapisLazuli;
                        break;
                      case 3:
                        levelTitle = AppLocalizations.of(context)!.uds_level_3;
                        levelDescription = AppLocalizations.of(
                          context,
                        )!.uds_level_3_description;
                        levelColor = AppColors.lapisLazuli;
                        break;
                    }

                    bool isCurrentLevel = widget.user['level'] == level;

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrentLevel
                            ? levelColor.withValues(alpha: 0.1)
                            : Theme.of(context).cardTheme.color,
                        border: Border.all(
                          color: isCurrentLevel
                              ? levelColor
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[600]!
                                    : Colors.grey.shade300),
                          width: isCurrentLevel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isCurrentLevel
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _confirmLevelChange(level);
                                },
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCurrentLevel
                                        ? levelColor
                                        : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[700]
                                              : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    color: isCurrentLevel
                                        ? Colors.white
                                        : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[400]
                                              : Colors.grey[600]),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        levelTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrentLevel
                                              ? levelColor
                                              : Theme.of(
                                                  context,
                                                ).textTheme.titleMedium?.color,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        levelDescription,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrentLevel)
                                  Icon(
                                    Icons.check_circle,
                                    color: levelColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context)!.uds_cancle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _confirmLevelChange(int newLevel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String levelName = '';
        Color levelColor = Colors.grey;

        switch (newLevel) {
          case 1:
            levelName = AppLocalizations.of(context)!.uds_level_1;
            levelColor = Colors.red;
            break;
          case 2:
            levelName = AppLocalizations.of(context)!.uds_level_2;
            levelColor = Color(0xFF007BA7);
            break;
          case 3:
            levelName = AppLocalizations.of(context)!.uds_level_3;
            levelColor = Color(0xFF007BA7);
            break;
        }

        return AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Directionality(
            textDirection: Localizations.localeOf(context).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: levelColor, size: 24),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.uds_confirm_level_title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          content: Directionality(
            textDirection: Localizations.localeOf(context).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppLocalizations.of(context)!.uds_question_part_1} "${widget.user['user']['username']}" ${AppLocalizations.of(context)!.uds_question_part_2}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: levelColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: levelColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context)!.uds_new_level} $levelName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context)!.uds_no,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      editUserLevel(newLevel);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: levelColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size(0, 44),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context)!.uds_yes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final user = widget.user;
    final theme = Theme.of(context);
    final ui = UiScale(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.scale(base: 16, min: 12, max: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Back arrow
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.uds_user_info,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                    ],
                  ),

                  // Right - Logo
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
      body: loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.lapisLazuli,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.uds_loading,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            )
          : Directionality(
              textDirection:
                  Provider.of<SettingsProvider>(
                        context,
                        listen: false,
                      ).selectedLanguage ==
                      'en'
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              child: Container(
                color: theme.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    ui.scale(base: 16, min: 12, max: 20),
                    ui.scale(base: 16, min: 12, max: 20),
                    ui.scale(base: 16, min: 12, max: 20),
                    ui.scale(base: 16, min: 12, max: 20) +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compact User Profile Header
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui.scale(base: 20, min: 14, max: 24),
                          vertical: ui.scale(base: 13, min: 10, max: 16),
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
                            ui.scale(base: 16, min: 12, max: 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lapisLazuli.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: ui.scale(base: 35, min: 28, max: 40),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: CircleAvatar(
                                radius: ui.scale(base: 30, min: 24, max: 36),
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person,
                                  size: ui.scale(base: 35, min: 28, max: 42),
                                  color: AppColors.lapisLazuli,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: ui.scale(base: 16, min: 12, max: 20),
                            ),
                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['user']?['username'] ??
                                        user['username'] ??
                                        AppLocalizations.of(context)!.uds_user,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ui.scale(
                                        base: 20,
                                        min: 16,
                                        max: 22,
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    height: ui.scale(base: 4, min: 3, max: 6),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: ui.scale(
                                        base: 10,
                                        min: 8,
                                        max: 12,
                                      ),
                                      vertical: ui.scale(
                                        base: 4,
                                        min: 3,
                                        max: 6,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        ui.scale(base: 12, min: 10, max: 14),
                                      ),
                                    ),
                                    child: Text(
                                      _getLevelText(user['level']),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: ui.scale(
                                          base: 12,
                                          min: 10,
                                          max: 14,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: ui.scale(base: 8, min: 6, max: 12),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        isUserActive
                                            ? Icons.check_circle_outline
                                            : Icons.cancel_outlined,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        size: ui.scale(
                                          base: 14,
                                          min: 12,
                                          max: 16,
                                        ),
                                      ),
                                      SizedBox(
                                        width: ui.scale(
                                          base: 4,
                                          min: 3,
                                          max: 6,
                                        ),
                                      ),
                                      Text(
                                        isUserActive
                                            ? AppLocalizations.of(
                                                context,
                                              )!.uds_active
                                            : AppLocalizations.of(
                                                context,
                                              )!.uds_inactive,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: ui.scale(
                                            base: 12,
                                            min: 10,
                                            max: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status Indicator
                            Container(
                              padding: EdgeInsets.all(
                                ui.scale(base: 8, min: 6, max: 10),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 12, min: 10, max: 14),
                                ),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: ui.scale(base: 20, min: 16, max: 24),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // User Information Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.lapisLazuli,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.uds_user_info,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildInfoTile(
                              Icons.email,
                              AppLocalizations.of(context)!.uds_email,
                              user['email'],
                            ),
                            _buildInfoTile(
                              Icons.phone,
                              AppLocalizations.of(context)!.uds_phone,
                              user['phone'],
                            ),
                            _buildInfoTile(
                              Icons.code,
                              AppLocalizations.of(context)!.uds_code,
                              user['code'].toString(),
                            ),
                            _buildInfoTile(
                              Icons.location_on,
                              AppLocalizations.of(context)!.uds_address,
                              user['address'],
                            ),
                            _buildInfoTile(
                              Icons.location_city,
                              AppLocalizations.of(context)!.uds_city,
                              user['city'],
                            ),
                            _buildInfoTile(
                              Icons.verified_user,
                              AppLocalizations.of(context)!.uds_status,
                              isUserActive
                                  ? AppLocalizations.of(context)!.uds_active
                                  : AppLocalizations.of(context)!.uds_inactive,
                              statusColor: isUserActive
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButton(
                        icon: Icons.admin_panel_settings,
                        title: AppLocalizations.of(
                          context,
                        )!.uds_change_level_access,
                        subtitle: AppLocalizations.of(
                          context,
                        )!.uds_change_level_access_description,
                        color: AppColors.lapisLazuli,
                        onTap: showLevelSelectionDialog,
                      ),

                      SizedBox(height: 12),

                      _buildActionButton(
                        icon: Icons.devices,
                        title: AppLocalizations.of(
                          context,
                        )!.uds_allowed_devices,
                        subtitle: AppLocalizations.of(
                          context,
                        )!.uds_manage_allowed_devices,
                        color: AppColors.lapisLazuli,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UserAllowedDevicesScreen(widget.user),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 12),

                      // Show action buttons only if user has permission to manage this user
                      if (_canManageUser()) ...[
                        _buildActionButton(
                          icon: loading
                              ? Icons.hourglass_empty
                              : isUserActive
                              ? Icons.block
                              : Icons.check_circle,
                          title: loading
                              ? AppLocalizations.of(context)!.uds_loading
                              : isUserActive
                              ? AppLocalizations.of(context)!.uds_disable_user
                              : AppLocalizations.of(context)!.uds_enable_user,
                          subtitle: loading
                              ? AppLocalizations.of(context)!.uds_wait
                              : isUserActive
                              ? AppLocalizations.of(context)!.uds_disable_access
                              : AppLocalizations.of(context)!.uds_enable_access,
                          color: loading ? Colors.grey : AppColors.lapisLazuli,
                          onTap: loading
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => Directionality(
                                      textDirection:
                                          Localizations.localeOf(
                                                context,
                                              ).languageCode ==
                                              'en'
                                          ? TextDirection.ltr
                                          : TextDirection.rtl,
                                      child: AlertDialog(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).cardTheme.color,
                                        surfaceTintColor: Colors.transparent,
                                        insetPadding: EdgeInsets.symmetric(
                                          horizontal: UiScale(
                                            context,
                                          ).scale(base: 16, min: 12, max: 20),
                                          vertical: UiScale(
                                            context,
                                          ).scale(base: 24, min: 16, max: 28),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            UiScale(
                                              context,
                                            ).scale(base: 20, min: 14, max: 24),
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                UiScale(context).scale(
                                                  base: 8,
                                                  min: 6,
                                                  max: 10,
                                                ),
                                              ),
                                              decoration: BoxDecoration(
                                                color: isUserActive
                                                    ? Colors.orange.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.green.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      UiScale(context).scale(
                                                        base: 12,
                                                        min: 10,
                                                        max: 14,
                                                      ),
                                                    ),
                                              ),
                                              child: Icon(
                                                isUserActive
                                                    ? Icons
                                                          .warning_amber_rounded
                                                    : Icons.check_circle,
                                                color: isUserActive
                                                    ? Colors.orange
                                                    : Colors.green,
                                                size: UiScale(context).scale(
                                                  base: 24,
                                                  min: 20,
                                                  max: 28,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: UiScale(context).scale(
                                                base: 12,
                                                min: 8,
                                                max: 16,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.uds_confirm_status_title,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: UiScale(context)
                                                      .scale(
                                                        base: 18,
                                                        min: 16,
                                                        max: 20,
                                                      ),
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.color,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.uds_confirm_status_msg,
                                              style: TextStyle(
                                                fontSize: UiScale(context)
                                                    .scale(
                                                      base: 16,
                                                      min: 14,
                                                      max: 18,
                                                    ),
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(
                                              height: UiScale(context).scale(
                                                base: 16,
                                                min: 12,
                                                max: 20,
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.all(
                                                UiScale(context).scale(
                                                  base: 16,
                                                  min: 12,
                                                  max: 20,
                                                ),
                                              ),
                                              decoration: BoxDecoration(
                                                color: isUserActive
                                                    ? Colors.orange.withValues(
                                                        alpha: 0.05,
                                                      )
                                                    : Colors.green.withValues(
                                                        alpha: 0.05,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      UiScale(context).scale(
                                                        base: 12,
                                                        min: 10,
                                                        max: 14,
                                                      ),
                                                    ),
                                                border: Border.all(
                                                  color: isUserActive
                                                      ? Colors.orange
                                                            .withValues(
                                                              alpha: 0.2,
                                                            )
                                                      : Colors.green.withValues(
                                                          alpha: 0.2,
                                                        ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isUserActive
                                                        ? Icons.block
                                                        : Icons.check_circle,
                                                    color:
                                                        AppColors.lapisLazuli,
                                                    size: UiScale(context)
                                                        .scale(
                                                          base: 20,
                                                          min: 18,
                                                          max: 24,
                                                        ),
                                                  ),
                                                  SizedBox(
                                                    width: UiScale(context)
                                                        .scale(
                                                          base: 12,
                                                          min: 8,
                                                          max: 16,
                                                        ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          isUserActive
                                                              ? AppLocalizations.of(
                                                                  context,
                                                                )!.uds_disable_user
                                                              : AppLocalizations.of(
                                                                  context,
                                                                )!.uds_enable_user,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: isUserActive
                                                                ? Colors.orange
                                                                : Colors.green,
                                                            fontSize:
                                                                UiScale(
                                                                  context,
                                                                ).scale(
                                                                  base: 14,
                                                                  min: 12,
                                                                  max: 16,
                                                                ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height:
                                                              UiScale(
                                                                context,
                                                              ).scale(
                                                                base: 4,
                                                                min: 3,
                                                                max: 6,
                                                              ),
                                                        ),
                                                        Text(
                                                          isUserActive
                                                              ? AppLocalizations.of(
                                                                  context,
                                                                )!.uds_disable_access_description
                                                              : AppLocalizations.of(
                                                                  context,
                                                                )!.uds_enable_access_description,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.color,
                                                            fontSize:
                                                                UiScale(
                                                                  context,
                                                                ).scale(
                                                                  base: 12,
                                                                  min: 10,
                                                                  max: 14,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                                ),
                                                child: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.uds_cancle,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Color(
                                                    0xFF007BA7,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 24,
                                                    vertical: 12,
                                                  ),
                                                ),
                                                child: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.uds_confirm,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (confirmed ?? false) toggleActive();
                                },
                        ),

                        SizedBox(height: 12),

                        _buildActionButton(
                          icon: Icons.delete_forever,
                          title: AppLocalizations.of(context)!.uds_delete_user,
                          subtitle: AppLocalizations.of(
                            context,
                          )!.uds_delete_user_description,
                          color: Colors.red,
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => Directionality(
                                textDirection:
                                    Localizations.localeOf(
                                          context,
                                        ).languageCode ==
                                        'en'
                                    ? TextDirection.ltr
                                    : TextDirection.rtl,
                                child: AlertDialog(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).cardTheme.color,
                                  surfaceTintColor: Colors.transparent,
                                  insetPadding: EdgeInsets.symmetric(
                                    horizontal: UiScale(
                                      context,
                                    ).scale(base: 16, min: 12, max: 20),
                                    vertical: UiScale(
                                      context,
                                    ).scale(base: 24, min: 16, max: 28),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      UiScale(
                                        context,
                                      ).scale(base: 20, min: 14, max: 24),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          UiScale(
                                            context,
                                          ).scale(base: 8, min: 6, max: 10),
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            UiScale(
                                              context,
                                            ).scale(base: 12, min: 10, max: 14),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red,
                                          size: UiScale(
                                            context,
                                          ).scale(base: 24, min: 20, max: 28),
                                        ),
                                      ),
                                      SizedBox(
                                        width: UiScale(
                                          context,
                                        ).scale(base: 12, min: 8, max: 16),
                                      ),
                                      Expanded(
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.uds_delete_user_title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: UiScale(
                                              context,
                                            ).scale(base: 18, min: 16, max: 20),
                                            color: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.uds_delete_user_message,
                                        style: TextStyle(
                                          fontSize: UiScale(
                                            context,
                                          ).scale(base: 16, min: 14, max: 18),
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(
                                        height: UiScale(
                                          context,
                                        ).scale(base: 16, min: 12, max: 20),
                                      ),
                                      Container(
                                        padding: EdgeInsets.all(
                                          UiScale(
                                            context,
                                          ).scale(base: 16, min: 12, max: 20),
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            UiScale(
                                              context,
                                            ).scale(base: 12, min: 10, max: 14),
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withValues(
                                              alpha: 0.2,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_forever,
                                              color: Colors.red,
                                              size: UiScale(context).scale(
                                                base: 20,
                                                min: 18,
                                                max: 24,
                                              ),
                                            ),
                                            SizedBox(
                                              width: UiScale(context).scale(
                                                base: 12,
                                                min: 8,
                                                max: 16,
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.uds_delete_full_user,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.red,
                                                      fontSize: UiScale(context)
                                                          .scale(
                                                            base: 14,
                                                            min: 12,
                                                            max: 16,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: UiScale(context)
                                                        .scale(
                                                          base: 4,
                                                          min: 3,
                                                          max: 6,
                                                        ),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.uds_delete_user_description2,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.color,
                                                      fontSize: UiScale(context)
                                                          .scale(
                                                            base: 12,
                                                            min: 10,
                                                            max: 14,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.uds_cancle,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.uds_delete,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (confirmed ?? false) deleteUser();
                          },
                        ),
                      ], // End of permission check
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _getLevelText(int level) {
    switch (level) {
      case 1:
        return AppLocalizations.of(context)!.uds_level_1;
      case 2:
        return AppLocalizations.of(context)!.uds_level_2;
      case 3:
        return AppLocalizations.of(context)!.uds_level_3;
      default:
        return AppLocalizations.of(context)!.uds_unknown;
    }
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    dynamic value, {
    Color? statusColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  statusColor ?? AppColors.lapisLazuli.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: statusColor ?? AppColors.lapisLazuli,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value?.toString() ?? '-',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
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
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
