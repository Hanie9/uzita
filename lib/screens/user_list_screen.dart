import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/screens/user_detail_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ui_scale.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List users = [];
  int selectedNavIndex = 4; // Users tab
  int userLevel = 3;
  String username = '';
  String userLevelTitle = '';
  String userRoleTitle = '';
  bool userModir = false;
  bool isLoading = true; // Add loading state
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // فیلترها
  String? filterUsername;
  String? filterPhone;
  String? filterLevel;
  String? filterActive;

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      userLevel = prefs.getInt('level') ?? 3;
      userModir = prefs.getBool('modir') ?? false;

      // Set user role title
      if (userModir) {
        userRoleTitle = AppLocalizations.of(
          context,
        )!.uls_company_representative;
      } else if (userLevel == 2) {
        userRoleTitle = AppLocalizations.of(context)!.uls_installer;
      } else if (userLevel == 3) {
        userRoleTitle = AppLocalizations.of(context)!.uls_user;
      } else if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.uls_admin;
      }
    });
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true; // Set loading to true when starting to fetch
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String url = '$baseUrl/listuser/';
      Map<String, String> queryParams = {};

      if (filterUsername != null && filterUsername!.isNotEmpty) {
        queryParams['username'] = filterUsername!;
      }
      if (filterPhone != null && filterPhone!.isNotEmpty) {
        queryParams['phone'] = filterPhone!;
      }
      if (filterLevel != null && filterLevel!.isNotEmpty) {
        queryParams['level'] = filterLevel!;
      }
      if (filterActive != null && filterActive!.isNotEmpty) {
        queryParams['is_active'] = filterActive!;
      }

      // Cache-busting timestamp
      queryParams['ts'] = DateTime.now().millisecondsSinceEpoch.toString();

      if (queryParams.isNotEmpty) {
        url += '?${Uri(queryParameters: queryParams).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      print('Users API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);

        List<dynamic> parsedUsers = [];
        if (data is List) {
          parsedUsers = data;
        } else if (data is Map && data['results'] is List) {
          parsedUsers = List.from(data['results'] as List);
        } else if (data is Map && data['data'] is List) {
          parsedUsers = List.from(data['data'] as List);
        } else if (data is Map && data['error'] != null) {
          // Show backend error message directly
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['error'].toString())));
          return;
        } else {
          // Unexpected shape
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.uls_bad_response),
            ),
          );
          return;
        }

        setState(() {
          users = parsedUsers;
          isLoading = false; // Set loading to false when data is loaded
        });
      } else if (response.statusCode == 403) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.uls_no_access)),
        );
      } else {
        setState(() {
          isLoading = false; // Set loading to false on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.uls_error_fetching_users}: (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false; // Set loading to false on exception
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.uls_error_connecting),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _loadUserData();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    // Handle navigation based on user level
    if (userLevel == 1) {
      // Service team lead navigation: Home (0), Profile (1), Missions (2), Users (4)
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Missions (organization tasks)
          Navigator.pushReplacementNamed(
            context,
            '/technician-reports',
          );
          break;
        case 3: // Reports
          Navigator.pushReplacementNamed(
            context,
            '/technician-organ-tasks',
          );
          break;
        case 4: // Users - already here
          break;
      }
    } else {
      // Original navigation for other user levels
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Devices
          Navigator.pushReplacementNamed(context, '/devices');
          break;
        case 2: // Reports
          Navigator.pushReplacementNamed(context, '/commands');
          break;
        case 3: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 4: // Users - already here
          break;
      }
    }
  }

  void showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    int? level = 3; // Default to level 3 - کاربر عادی
    String message = '';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            actionsPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            title: Row(
              children: [
                Icon(Icons.person_add, color: Color(0xFF007BA7), size: 24),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.uls_add_user_title,
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
                  _buildAddUserField(
                    controller: usernameController,
                    label: AppLocalizations.of(context)!.uls_username,
                    icon: Icons.person,
                  ),
                  SizedBox(height: 16),
                  _buildAddUserField(
                    controller: passwordController,
                    label: AppLocalizations.of(context)!.uls_password,
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                  SizedBox(height: 16),
                  _buildPhoneUserField(
                    controller: phoneController,
                    label: AppLocalizations.of(context)!.uls_phone,
                    icon: Icons.phone,
                  ),
                  SizedBox(height: 16),
                  _buildAddUserField(
                    controller: codeController,
                    label: AppLocalizations.of(context)!.uls_user_code,
                    icon: Icons.code,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: DropdownButtonFormField<int>(
                      value: level ?? 3,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        )!.uls_access_level,
                        hintText: AppLocalizations.of(context)!.uls_level3,
                        prefixIcon: Icon(
                          Icons.admin_panel_settings,
                          color: Color(0xFF007BA7),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      isExpanded: true,
                      isDense: true,
                      menuMaxHeight: 280,
                      items: [
                        DropdownMenuItem(
                          value: 1,
                          child: Text(
                            AppLocalizations.of(context)!.uls_level1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(
                            AppLocalizations.of(context)!.uls_level2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(
                            AppLocalizations.of(context)!.uls_level3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          level = val;
                        });
                      },
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.contains('موفقیت')
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: message.contains('موفقیت')
                              ? Colors.blue
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            message.contains('موفقیت')
                                ? Icons.check_circle
                                : Icons.error,
                            color: message.contains('موفقیت')
                                ? Colors.blue
                                : Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                color: message.contains('موفقیت')
                                    ? Colors.blue
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                          AppLocalizations.of(context)!.uls_cancel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (usernameController.text.isEmpty ||
                                  passwordController.text.isEmpty ||
                                  phoneController.text.isEmpty ||
                                  codeController.text.isEmpty) {
                                setDialogState(() {
                                  message = AppLocalizations.of(
                                    context,
                                  )!.uls_fill_all;
                                });
                                return;
                              }

                              // Phone min length validation: ensure exactly 10 digits (after removing leading zero if present)
                              String phoneDigits = phoneController.text.trim();
                              if (phoneDigits.startsWith('0')) {
                                phoneDigits = phoneDigits.substring(1);
                              }
                              if (phoneDigits.length < 10) {
                                setDialogState(() {
                                  message = AppLocalizations.of(
                                    context,
                                  )!.uls_phone_length;
                                });
                                return;
                              }

                              setDialogState(() {
                                isLoading = true;
                                message = '';
                              });

                              try {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final token = prefs.getString('token');

                                // Default level to 3 if not chosen
                                final int levelToSend =
                                    (level == null || level == '')
                                    ? 3
                                    : int.tryParse('$level') ?? 3;

                                final response = await http.post(
                                  Uri.parse('$baseUrl/adduser/'),
                                  headers: {
                                    'Authorization': 'Bearer $token',
                                    'Content-Type': 'application/json',
                                  },
                                  body: json.encode({
                                    'username': usernameController.text.trim(),
                                    'password': passwordController.text,
                                    'phone': phoneDigits,
                                    'code': codeController.text.trim(),
                                    'level': levelToSend,
                                  }),
                                );

                                final data = json.decode(
                                  utf8.decode(response.bodyBytes),
                                );

                                setDialogState(() {
                                  message =
                                      data['massage'] ??
                                      data['error'] ??
                                      AppLocalizations.of(
                                        context,
                                      )!.uls_error_adding_user;
                                });

                                if (response.statusCode == 200 ||
                                    response.statusCode == 201) {
                                  // Refresh user list
                                  await fetchUsers();

                                  // Close dialog after a short delay
                                  Future.delayed(Duration(seconds: 2), () {
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                  });
                                }
                              } catch (e) {
                                setDialogState(() {
                                  message = AppLocalizations.of(
                                    context,
                                  )!.uls_error_connecting;
                                });
                              } finally {
                                setDialogState(() {
                                  isLoading = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
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
                      child: isLoading
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
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.uls_add_user_title,
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
          ),
        ),
      ),
    );
  }

  Widget _buildAddUserField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.lapisLazuli.withValues(alpha: 0.8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPhoneUserField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        onChanged: (value) {
          // حذف صفر اول به صورت خودکار
          if (value.startsWith('0') && value.length > 1) {
            String newValue = value.substring(1);
            controller.value = TextEditingValue(
              text: newValue,
              selection: TextSelection.collapsed(offset: newValue.length),
            );
          }
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.lapisLazuli.withValues(alpha: 0.8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void showFilterDialog() {
    final usernameController = TextEditingController(text: filterUsername);
    final phoneController = TextEditingController(text: filterPhone);
    String levelValue = filterLevel ?? '';
    String activeValue = filterActive ?? '';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.filter_list,
                color: AppColors.lapisLazuli.withValues(alpha: 0.8),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.uls_filter_users,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterField(
                  controller: usernameController,
                  label: AppLocalizations.of(context)!.uls_username,
                  icon: Icons.person,
                ),
                SizedBox(height: 16),
                _buildFilterField(
                  controller: phoneController,
                  label: AppLocalizations.of(context)!.uls_phone_label,
                  icon: Icons.phone,
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: levelValue.isEmpty ? null : levelValue,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.uls_access_level,
                      prefixIcon: Icon(
                        Icons.admin_panel_settings,
                        color: AppColors.lapisLazuli.withValues(alpha: 0.8),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '1',
                        child: Text(AppLocalizations.of(context)!.uls_admin),
                      ),
                      DropdownMenuItem(
                        value: '2',
                        child: Text(
                          AppLocalizations.of(context)!.uls_installer,
                        ),
                      ),
                      DropdownMenuItem(
                        value: '3',
                        child: Text(AppLocalizations.of(context)!.uls_user),
                      ),
                    ],
                    onChanged: (val) {
                      levelValue = val ?? '';
                    },
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[600]!
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: activeValue.isEmpty ? null : activeValue,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      )!.uls_active_status,
                      prefixIcon: Icon(
                        Icons.check_circle,
                        color: AppColors.lapisLazuli.withValues(alpha: 0.8),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'true',
                        child: Text(AppLocalizations.of(context)!.uls_active),
                      ),
                      DropdownMenuItem(
                        value: 'false',
                        child: Text(AppLocalizations.of(context)!.uls_inactive),
                      ),
                    ],
                    onChanged: (val) {
                      activeValue = val!;
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.uls_cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  filterUsername = usernameController.text;
                  filterPhone = phoneController.text;
                  filterLevel = levelValue;
                  filterActive = activeValue;
                });
                fetchUsers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapisLazuli.withValues(alpha: 0.8),
                textStyle: TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.uls_apply,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[600]!
              : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.lapisLazuli.withValues(alpha: 0.8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map user, int index) {
    final userData = user['user'];
    final username = userData['username'] ?? '---';
    final level = user['level']?.toString() ?? '-';
    final code = user['code']?.toString() ?? '-';
    final isActive = user['active'] ?? false;

    // Normalize role title for each user to match the rest of the app and drawer
    String userRoleTitle = '';
    Color levelColor = Colors.grey;
    final bool isModir =
        (user['modir'] == true) || (userData?['modir'] == true);

    if (isModir) {
      userRoleTitle = AppLocalizations.of(context)!.uls_company_representative;
      levelColor = Colors.red;
    } else if (level == '1') {
      userRoleTitle = AppLocalizations.of(context)!.uls_admin;
      levelColor = Colors.red;
    } else if (level == '2') {
      userRoleTitle = AppLocalizations.of(context)!.uls_installer;
      levelColor = Colors.orange;
    } else if (level == '3') {
      userRoleTitle = AppLocalizations.of(context)!.uls_user;
      levelColor = const Color(0xFF007BA7);
    }

    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserDetailScreen(user)),
            );

            // If changes were made, refresh the user list
            if (result == true) {
              fetchUsers();
            }
          },
          child: Padding(
            padding: EdgeInsets.all(
              UiScale(context).scale(base: 20, min: 12, max: 22),
            ),
            child: Row(
              children: [
                // User Avatar
                Container(
                  width: UiScale(context).scale(base: 60, min: 48, max: 68),
                  height: UiScale(context).scale(base: 60, min: 48, max: 68),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [levelColor, levelColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: levelColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                ),
                SizedBox(width: 16),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive
                                  ? AppLocalizations.of(context)!.uls_active
                                  : AppLocalizations.of(context)!.uls_inactive,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            level == '3'
                                ? Icons.person
                                : Icons.admin_panel_settings,
                            color: levelColor,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            userRoleTitle,
                            style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.code, color: Colors.grey[600], size: 16),
                          SizedBox(width: 6),
                          Text(
                            '${AppLocalizations.of(context)!.uls_code}: $code',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
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
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.notifications,
                            color: theme.appBarTheme.iconTheme?.color,
                          ),
                          onPressed: () {
                            // TODO: Implement notifications
                          },
                        ),
                      ],
                    ),

                    // Center - Text
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.uls_title,
                          style: theme.appBarTheme.titleTextStyle,
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
          userModir: userModir,
          userLevel: userLevel,
          refreshUserData: _loadUserData,
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
        body: Directionality(
          textDirection: Localizations.localeOf(context).languageCode == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: Column(
            children: [
              // Compact Header Section with Stats
              Container(
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
                        Icons.group,
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
                                AppLocalizations.of(context)!.uls_users_header,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                      children: [
                                  Icon(
                                    Icons.list_alt,
                                    color: Colors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  isLoading
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                    )
                                  : Text(
                                      '${users.length} ${AppLocalizations.of(context)!.uls_users_count}',
                                      style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 12,
                                          ),
                                      ),
                                ],
                                    ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ui.scale(base: 8, min: 6, max: 10),
                              vertical: ui.scale(base: 4, min: 3, max: 6),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 8, min: 6, max: 10),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.white,
                                  size: ui.scale(base: 16, min: 14, max: 18),
                                ),
                                SizedBox(
                                  width: ui.scale(base: 4, min: 3, max: 6),
                                ),
                                Text(
                                  AppLocalizations.of(context)!.uls_manager,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.add_box,
                        title: AppLocalizations.of(context)!.uls_add_user,
                        color: Color.fromARGB(255, 52, 100, 231),
                        onTap: showAddUserDialog,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.filter_list,
                        title: AppLocalizations.of(context)!.uls_filter,
                        color: Color.fromARGB(255, 52, 100, 231),
                        onTap: showFilterDialog,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Users List
              Expanded(
                child: isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.lapisLazuli.withValues(
                                        alpha: 0.1,
                                      )
                                    : AppColors.lapisLazuli.withValues(
                                        alpha: 0.05,
                                      ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.lapisLazuli.withValues(
                                    alpha: 0.2,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.lapisLazuli,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              AppLocalizations.of(context)!.uls_loading_users,
                              style: TextStyle(
                                color: AppColors.lapisLazuli,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.loading_please_wait_short,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await fetchUsers();
                        },
                        color: AppColors.lapisLazuli,
                        child: users.isEmpty
                            ? ListView(
                                physics: AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.3,
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 64,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[600]
                                              : Colors.grey[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.uls_no_users_found,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.color,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.uls_refresh_users,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                itemCount: users.length,
                                itemBuilder: (context, i) =>
                                    _buildUserCard(users[i], i),
                              ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SharedBottomNavigation(
          selectedIndex: selectedNavIndex,
          userLevel: userLevel,
          onItemTapped: _onNavItemTapped,
        ),
      ),
    );
  }

  // PopScope handles back; removed old WillPop handler

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
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
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
