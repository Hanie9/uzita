import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/app_localizations.dart';
import 'dart:convert';
import 'package:uzita/services.dart'
    show baseUrl5, AppColors; // reuse API base URL and colors
import 'package:uzita/screens/editpassword_screen.dart';
import 'package:uzita/screens/help_screen.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/screens/settings_screen.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/utils/shared_loading.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/utils/ui_scale.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = '';
  String userRoleTitle = '';
  int userLevel = 3;
  bool isLoading = true;
  bool userActive = false;
  int selectedNavIndex = 3;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Profile fields
  String? firstName;
  String? lastName;
  String? phone;
  String? userCode;
  String? address;
  String? city;
  bool? active;
  int? organ;
  String? createdAtIso;
  int? level;
  List<dynamic> allowedDevices = [];
  String? organName;

  // Controllers for editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      // Only fetch profile if user is active
      if (userActive) {
        _fetchProfile();
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      userLevel = prefs.getInt('level') ?? 3;
      userActive = prefs.getBool('active') ?? false;

      // Set user role title (modir overrides level)
      final bool isModir = prefs.getBool('modir') ?? false;
      if (isModir) {
        userRoleTitle = AppLocalizations.of(
          context,
        )!.pro_company_representative;
      } else if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (userLevel == 2) {
        userRoleTitle = AppLocalizations.of(context)!.pro_installer;
      } else {
        userRoleTitle = AppLocalizations.of(context)!.pro_user;
      }

      // If user is not active, stop loading immediately
      if (!userActive) {
        isLoading = false;
      }
    });
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl5/profile/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      print('Profile API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        print(
          'Profile API body (prefix): ${body.length > 200 ? body.substring(0, 200) : body}',
        );
        final dynamic dataDyn = json.decode(body);

        if (dataDyn is Map && dataDyn['error'] != null) {
          setState(() => isLoading = false);
          if (userActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(dataDyn['error'].toString())),
            );
          }
          return;
        }

        if (dataDyn is! Map) {
          setState(() => isLoading = false);
          if (userActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.pro_unexpected_response,
                ),
              ),
            );
          }
          return;
        }

        final Map<String, dynamic> data = Map<String, dynamic>.from(dataDyn);
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> profile = Map<String, dynamic>.from(
          (data['profile'] ?? {}),
        );
        final Map<String, dynamic> user = Map<String, dynamic>.from(
          (profile['user'] ?? {}),
        );

        setState(() {
          username = (user['username'] ?? username)?.toString() ?? '';
          firstName = user['first_name'];
          lastName = user['last_name'];
          phone = profile['phone']?.toString();
          userCode = profile['code']?.toString();
          address = profile['address']?.toString();
          city = profile['city']?.toString();
          active = profile['active'] == true;
          organ = profile['organ'];
          createdAtIso = profile['created_at']?.toString();
          level = profile['level'] is int
              ? profile['level']
              : int.tryParse('${profile['level']}');
          allowedDevices = (profile['allowed_devices'] as List?) ?? [];
          organName = data['organ_name']?.toString();

          // Update role title from fetched level (modir overrides)
          if (level != null) {
            userLevel = level!;
            final bool isModir =
                (profile['modir'] == true) ||
                (data['modir'] == true) ||
                (prefs.getBool('modir') ?? false);
            if (isModir) {
              userRoleTitle = AppLocalizations.of(
                context,
              )!.pro_company_representative;
            } else if (userLevel == 1) {
              userRoleTitle = AppLocalizations.of(context)!.pro_admin;
            } else if (userLevel == 2) {
              userRoleTitle = AppLocalizations.of(context)!.pro_installer;
            } else {
              userRoleTitle = AppLocalizations.of(context)!.pro_user;
            }
          }

          // Seed controllers
          _firstNameController.text = (firstName ?? '');
          _lastNameController.text = (lastName ?? '');
          _cityController.text = (city ?? '');
          _addressController.text = (address ?? '');

          isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() => isLoading = false);
        if (userActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.pro_no_access),
            ),
          );
        }
      } else {
        setState(() => isLoading = false);
        if (userActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.pro_error_fetching_profile,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Profile API error: $e');
      if (userActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pro_error_connecting),
          ),
        );
      }
    }
  }

  bool isSaving = false;
  Future<bool> _saveProfileWithValues({
    required String? firstNameValue,
    required String? lastNameValue,
    required String? cityValue,
    required String? addressValue,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String? sanitize(String? value) {
        if (value == null) return null;
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }

      String finalizeRequired(String? input, String? previous) {
        final sanitized = sanitize(input);
        if (sanitized != null) return sanitized;
        if (previous != null && previous.trim().isNotEmpty) return previous;
        return '';
      }

      String? finalizeOptional(String? input, String? previous) {
        final sanitized = sanitize(input);
        if (sanitized != null) return sanitized;
        return previous; // may be null
      }

      final payload = {
        'first_name': finalizeRequired(firstNameValue, firstName),
        'last_name': finalizeRequired(lastNameValue, lastName),
        'city': finalizeOptional(cityValue, city),
        'address': finalizeOptional(addressValue, address),
      };

      final body = json.encode(payload);

      final response = await http.put(
        Uri.parse('$baseUrl5/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pro_update_profile_success,
            ),
          ),
        );
        await _fetchProfile();
        return true;
      } else {
        final err = response.body.isNotEmpty
            ? utf8.decode(response.bodyBytes)
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.pro_update_profile_error}: ${err.isNotEmpty ? err : response.statusCode.toString()}',
            ),
          ),
        );
        print(response.body);
        return false;
      }
    } catch (e) {
      // Only show error snackbar for active users
      if (userActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.pro_error_connecting),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _openEditDialog() async {
    final TextEditingController firstCtrl = TextEditingController(text: '');
    final TextEditingController lastCtrl = TextEditingController(text: '');
    final TextEditingController cityCtrl = TextEditingController(text: '');
    final TextEditingController addrCtrl = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit, color: const Color(0xFF007BA7)),
                  SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.pro_edit_profile,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dialogTextField(
                      controller: firstCtrl,
                      label: AppLocalizations.of(context)!.pro_name,
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 12),
                    _dialogTextField(
                      controller: lastCtrl,
                      label: AppLocalizations.of(context)!.pro_last_name,
                      icon: Icons.person,
                    ),
                    SizedBox(height: 12),
                    _dialogTextField(
                      controller: cityCtrl,
                      label: AppLocalizations.of(context)!.pro_city,
                      icon: Icons.location_city,
                    ),
                    SizedBox(height: 12),
                    _dialogTextField(
                      controller: addrCtrl,
                      label: AppLocalizations.of(context)!.pro_address,
                      icon: Icons.home_outlined,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    AppLocalizations.of(context)!.pro_cancle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BA7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          final ok = await _saveProfileWithValues(
                            firstNameValue: firstCtrl.text,
                            lastNameValue: lastCtrl.text,
                            cityValue: cityCtrl.text,
                            addressValue: addrCtrl.text,
                          );
                          if (ok && context.mounted) {
                            // Clear fields and close dialog
                            firstCtrl.clear();
                            lastCtrl.clear();
                            cityCtrl.clear();
                            addrCtrl.clear();
                            Navigator.of(dialogContext).pop();
                          }
                          setDialogState(() => submitting = false);
                        },
                  icon: submitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(Icons.save, color: Colors.white),
                  label: Text(
                    AppLocalizations.of(context)!.pro_save,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfileSection({
    required String title,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    // Handle navigation based on selected index
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final ui = UiScale(context);

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
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor,
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
                              color: theme.appBarTheme.iconTheme?.color,
                            ),
                            onPressed: () => Scaffold.of(context).openDrawer(),
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
                        child: Text(
                          AppLocalizations.of(context)!.pro_title,
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
        drawer: SharedAppDrawer(
          username: username,
          userRoleTitle: userRoleTitle,
          userModir: userLevel == 1,
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
          refreshUserData: _loadUserData,
          userLevel: userLevel,
        ),
        body: isLoading
            ? Center(
                child: SharedLoading(
                  title: AppLocalizations.of(context)!.pro_loading_profile,
                ),
              )
            : userActive
            ? RefreshIndicator(
                onRefresh: _fetchProfile,
                color: AppColors.lapisLazuli,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Directionality(
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
                        // Compact Profile Header
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: ui.scale(base: 16, min: 12, max: 20),
                            vertical: ui.scale(base: 6, min: 4, max: 10),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: ui.scale(base: 20, min: 14, max: 24),
                            vertical: ui.scale(base: 12, min: 10, max: 16),
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
                                blurRadius: ui.scale(base: 8, min: 6, max: 12),
                                offset: Offset(
                                  0,
                                  ui.scale(base: 3, min: 2, max: 4),
                                ),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(
                            minHeight: ui.scale(base: 78, min: 66, max: 96),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                      (firstName ?? '').isNotEmpty ||
                                              (lastName ?? '').isNotEmpty
                                          ? '${firstName ?? ''} ${lastName ?? ''}'
                                                .trim()
                                          : username,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: ui.scale(
                                          base: 20,
                                          min: 16,
                                          max: 22,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(
                                      height: ui.scale(base: 4, min: 3, max: 8),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: ui.scale(
                                          base: 10,
                                          min: 8,
                                          max: 14,
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
                                          ui.scale(base: 12, min: 10, max: 16),
                                        ),
                                      ),
                                      child: Text(
                                        userRoleTitle,
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
                                      height: ui.scale(
                                        base: 8,
                                        min: 6,
                                        max: 12,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.verified_user,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          size: ui.scale(
                                            base: 14,
                                            min: 12,
                                            max: 18,
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
                                          AppLocalizations.of(
                                            context,
                                          )!.pro_account_active,
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
                              // Edit Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    ui.scale(base: 12, min: 10, max: 16),
                                  ),
                                ),
                                padding: EdgeInsets.all(
                                  ui.scale(base: 4, min: 3, max: 8),
                                ),
                                child: SizedBox(
                                  width: ui.scale(base: 40, min: 34, max: 48),
                                  height: ui.scale(base: 40, min: 34, max: 48),
                                  child: IconButton(
                                    onPressed: _openEditDialog,
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: ui.scale(
                                        base: 20,
                                        min: 16,
                                        max: 24,
                                      ),
                                    ),
                                    tooltip: AppLocalizations.of(
                                      context,
                                    )!.pro_edit_profile,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Profile Content
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            ui.scale(base: 16, min: 12, max: 20),
                            ui.scale(base: 8, min: 6, max: 12),
                            ui.scale(base: 16, min: 12, max: 20),
                            ui.scale(base: 16, min: 12, max: 20),
                          ),
                          child: Column(
                            children: [
                              // Details display
                              _buildProfileSection(
                                title: AppLocalizations.of(
                                  context,
                                )!.pro_info_account,
                                child: Column(
                                  children: [
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_name_last_name,
                                      ((firstName ?? '').isNotEmpty ||
                                              (lastName ?? '').isNotEmpty)
                                          ? '${firstName ?? ''} ${lastName ?? ''}'
                                                .trim()
                                          : '—',
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_username,
                                      username.isNotEmpty ? username : '—',
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(context)!.pro_phone,
                                      (phone ?? '—'),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_user_code,
                                      (userCode ?? '—'),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(context)!.pro_address,
                                      (address ?? '—'),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(context)!.pro_city,
                                      (city ?? '—'),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_level_access,
                                      userRoleTitle.isNotEmpty
                                          ? userRoleTitle
                                          : '—',
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_organ_name,
                                      (organName ?? '—'),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_allowed_devices_count,
                                      allowedDevices.length.toString(),
                                    ),
                                    _kvRow(
                                      AppLocalizations.of(
                                        context,
                                      )!.pro_created_at,
                                      _formatDate(createdAtIso),
                                    ),
                                  ],
                                ),
                              ),

                              // Quick Actions
                              _buildProfileSection(
                                title: AppLocalizations.of(
                                  context,
                                )!.pro_quick_access,
                                subtitle: AppLocalizations.of(
                                  context,
                                )!.pro_quick_access_description,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.lock_outline),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.pro_change_password,
                                        style: TextStyle(
                                          fontSize: UiScale(
                                            context,
                                          ).scale(base: 16, min: 14, max: 18),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: UiScale(
                                          context,
                                        ).scale(base: 16, min: 14, max: 18),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ChangePasswordScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(
                                        Icons.notifications_outlined,
                                      ),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.pro_notification_settings,
                                        style: TextStyle(
                                          fontSize: UiScale(
                                            context,
                                          ).scale(base: 16, min: 14, max: 18),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: UiScale(
                                          context,
                                        ).scale(base: 16, min: 14, max: 18),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SettingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: Icon(Icons.help_outline),
                                      title: Text(
                                        AppLocalizations.of(context)!.pro_help,
                                        style: TextStyle(
                                          fontSize: UiScale(
                                            context,
                                          ).scale(base: 16, min: 14, max: 18),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios,
                                        size: UiScale(
                                          context,
                                        ).scale(base: 16, min: 14, max: 18),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HelpScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                Icons.person_off_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),

            SizedBox(height: 24),

            // Title
            Text(
              AppLocalizations.of(context)!.pro_waiting_for_activation,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),

            SizedBox(height: 12),

            // Description
            Text(
              AppLocalizations.of(
                context,
              )!.pro_waiting_for_activation_description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.5,
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
                        AppLocalizations.of(context)!.pro_contact_admin,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.pro_contact_admin_button,
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

  // Key-Value row for details
  Widget _kvRow(String keyLabel, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
            size: 18,
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              keyLabel,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.left
                  : TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      } else {
        final jdt = Jalali.fromDateTime(dt);
        return '${jdt.year}/${jdt.month.toString().padLeft(2, '0')}/${jdt.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return iso;
    }
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    final dir = Directionality.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textDirection: dir,
      textAlign: dir == TextDirection.rtl ? TextAlign.right : TextAlign.left,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lapisLazuli, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
