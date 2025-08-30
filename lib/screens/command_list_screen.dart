import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/main.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/utils/shared_loading.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';

class CommandListScreen extends StatefulWidget {
  const CommandListScreen({super.key});

  @override
  State<CommandListScreen> createState() => _CommandListScreenState();
}

class _CommandListScreenState extends State<CommandListScreen> {
  List commands = [];
  String? nextCursor;
  bool isLoading = false;
  bool isLoadingMore = false;

  String? filterDevice;
  String? filterUsername;
  String? filterCode;
  String? filterDate; // به صورت میلادی
  String? filterDateDisplay; // برای نمایش شمسی

  // Bottom navigation state
  int selectedNavIndex = 2; // Reports tab is active
  String username = '';
  int userLevel = 3;
  String userRoleTitle = '';
  bool userModir = false;
  bool userActive = false;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    loadUserData().then((_) {
      // Only fetch commands if user is active
      if (userActive) {
        fetchCommands();
      }
    });
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username =
          prefs.getString('username') ?? AppLocalizations.of(context)!.cls_user;
      userLevel = prefs.getInt('level') ?? 3;
      userModir = prefs.getBool('modir') ?? false;
      userActive = prefs.getBool('active') ?? false;
      userRoleTitle = _getUserRoleTitle(userLevel, userModir);
    });
  }

  String _getUserRoleTitle(int level, bool modir) {
    if (level == 1 && modir) {
      return AppLocalizations.of(context)!.cls_company_representative;
    } else if (level == 1) {
      return AppLocalizations.of(context)!.cls_admin;
    }
    switch (level) {
      case 2:
        return AppLocalizations.of(context)!.cls_installer;
      case 3:
        return AppLocalizations.of(context)!.cls_regular_user;
      default:
        return AppLocalizations.of(context)!.cls_user;
    }
  }

  Future<void> fetchCommands({bool reset = false}) async {
    try {
      if (reset) {
        setState(() {
          isLoading = true;
          isLoadingMore = false;
          commands.clear();
          nextCursor = null;
        });
      } else if (commands.isEmpty) {
        setState(() => isLoading = true);
      } else {
        setState(() => isLoadingMore = true);
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      Map<String, String> queryParams = {};
      if (userLevel == 3) {
        queryParams['username'] = username; // level 3 sees own only
      } else if (filterUsername != null && filterUsername!.isNotEmpty) {
        queryParams['username'] = filterUsername!;
      }
      if (filterDate != null && filterDate!.isNotEmpty) {
        queryParams['date'] = filterDate!;
      }
      // Apply optional filters when provided
      if (filterCode != null && filterCode!.isNotEmpty) {
        queryParams['code'] = filterCode!;
      }
      if (filterDevice != null && filterDevice!.isNotEmpty) {
        // Try both keys in case backend expects a specific one
        queryParams['device'] = filterDevice!;
        queryParams['device_name'] = filterDevice!;
      }
      if (nextCursor != null) {
        queryParams['cursor'] = nextCursor!;
      }
      // cache-busting
      queryParams['ts'] = DateTime.now().millisecondsSinceEpoch.toString();

      // Try multiple known endpoints to avoid 404 due to naming differences
      final endpoints = <String>[
        '$baseUrl/listcommand/',
        '$baseUrl/listcommands/',
        '$baseUrl/listreport/',
      ];

      http.Response? okResponse;
      String lastBody = '';
      int lastStatus = 0;

      for (final ep in endpoints) {
        final uri = Uri.parse(ep).replace(queryParameters: queryParams);
        await SessionManager().onNetworkRequest();
        final res = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Connection': 'close',
            'Accept': 'application/json; charset=utf-8',
            'Content-Type': 'application/json; charset=utf-8',
          },
        );
        lastStatus = res.statusCode;
        lastBody = utf8.decode(res.bodyBytes);
        if (res.statusCode == 200 && lastBody.trim().startsWith('{') ||
            lastBody.trim().startsWith('[')) {
          okResponse = res;
          break;
        }
      }

      if (okResponse == null) {
        // Show meaningful message based on last response
        String msg =
            '${AppLocalizations.of(context)!.cls_error_fetching_commands} ($lastStatus)';
        try {
          final dyn = json.decode(lastBody);
          if (dyn is Map &&
              (dyn['error'] != null ||
                  dyn['detail'] != null ||
                  dyn['message'] != null)) {
            msg = (dyn['error'] ?? dyn['detail'] ?? dyn['message']).toString();
          }
        } catch (_) {
          if (lastBody.startsWith('<!DOCTYPE html>')) {
            msg = AppLocalizations.of(context)!.cls_error_address;
          }
        }
        if (userActive) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      } else {
        final respBody = utf8.decode(okResponse.bodyBytes);

        final dynamic data = json.decode(respBody);
        if (data is Map && data['error'] != null) {
          if (userActive) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(data['error'].toString())));
          }
        } else if (data is Map && data['results'] is List) {
          // Client-side filtering fallback to ensure filters work even if server ignores params
          bool matchesFilters(Map<String, dynamic> command) {
            // Code filter
            if (filterCode != null && filterCode!.trim().isNotEmpty) {
              final commandCode = (command['code'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!commandCode.contains(filterCode!.trim().toLowerCase())) {
                return false;
              }
            }
            // Device name filter
            if (filterDevice != null && filterDevice!.trim().isNotEmpty) {
              final deviceName = (command['device']?['name'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!deviceName.contains(filterDevice!.trim().toLowerCase())) {
                return false;
              }
            }
            // Username filter (only applicable for level < 3, level 3 is handled server-side)
            if (userLevel < 3 &&
                filterUsername != null &&
                filterUsername!.trim().isNotEmpty) {
              final uname = (command['profile']?['user']?['username'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!uname.contains(filterUsername!.trim().toLowerCase())) {
                return false;
              }
            }
            // Date filter (compare only date part in YYYY-MM-DD)
            if (filterDate != null && filterDate!.trim().isNotEmpty) {
              final createdAtStr = (command['created_at'] ?? '').toString();
              try {
                final createdAt = DateTime.parse(createdAtStr).toLocal();
                final createdDateOnly =
                    "${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
                if (createdDateOnly != filterDate) {
                  return false;
                }
              } catch (_) {
                return false;
              }
            }
            return true;
          }

          final List<Map<String, dynamic>> fetched =
              List<Map<String, dynamic>>.from(data['results']);
          final List<Map<String, dynamic>> filtered = fetched
              .where((c) => matchesFilters(c))
              .toList();

          setState(() {
            if (reset) commands.clear();
            commands.addAll(filtered);
            nextCursor = data['next'] != null
                ? Uri.parse(data['next']).queryParameters['cursor']
                : null;
          });
        } else if (data is List) {
          bool matchesFilters(Map<String, dynamic> command) {
            if (filterCode != null && filterCode!.trim().isNotEmpty) {
              final commandCode = (command['code'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!commandCode.contains(filterCode!.trim().toLowerCase())) {
                return false;
              }
            }
            if (filterDevice != null && filterDevice!.trim().isNotEmpty) {
              final deviceName = (command['device']?['name'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!deviceName.contains(filterDevice!.trim().toLowerCase())) {
                return false;
              }
            }
            if (userLevel < 3 &&
                filterUsername != null &&
                filterUsername!.trim().isNotEmpty) {
              final uname = (command['profile']?['user']?['username'] ?? '')
                  .toString()
                  .toLowerCase();
              if (!uname.contains(filterUsername!.trim().toLowerCase())) {
                return false;
              }
            }
            if (filterDate != null && filterDate!.trim().isNotEmpty) {
              final createdAtStr = (command['created_at'] ?? '').toString();
              try {
                final createdAt = DateTime.parse(createdAtStr).toLocal();
                final createdDateOnly =
                    "${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}";
                if (createdDateOnly != filterDate) {
                  return false;
                }
              } catch (_) {
                return false;
              }
            }
            return true;
          }

          final List<Map<String, dynamic>> fetched =
              List<Map<String, dynamic>>.from(data);
          final List<Map<String, dynamic>> filtered = fetched
              .where((c) => matchesFilters(c))
              .toList();

          setState(() {
            if (reset) commands.clear();
            commands.addAll(filtered);
            nextCursor = null;
          });
        } else {
          if (userActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.cls_unexpected_error,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (userActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cls_error_connecting),
          ),
        );
      }
    }

    setState(() {
      isLoading = false;
      isLoadingMore = false;
    });
  }

  String formatLocalizedDate(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final isEnglish =
          Provider.of<SettingsProvider>(
            context,
            listen: false,
          ).selectedLanguage ==
          'en';
      if (isEnglish) {
        final date =
            "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
        final time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        return "$date | $time";
      } else {
        final jdt = Jalali.fromDateTime(dt);
        final date =
            "${jdt.year}/${jdt.month.toString().padLeft(2, '0')}/${jdt.day.toString().padLeft(2, '0')}";
        final time =
            "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        return "$date | $time";
      }
    } catch (e) {
      return "|";
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
      case 1: // Devices
        Navigator.pushReplacementNamed(context, '/devices');
        break;
      case 2: // Reports - already here
        break;
      case 3: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case 4: // Users
        Navigator.pushReplacementNamed(context, '/users');
        break;
    }
  }

  Widget _buildFilterButton() {
    final ui = UiScale(context);
    return Container(
      margin: EdgeInsets.symmetric(
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
          ui.scale(base: 16, min: 12, max: 20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lapisLazuli.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ui.scale(base: 16, min: 12, max: 20),
          ),
          onTap: showFilterDialog,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ui.scale(base: 20, min: 14, max: 24),
              vertical: ui.scale(base: 16, min: 12, max: 20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: ui.scale(base: 24, min: 20, max: 28),
                ),
                SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                Text(
                  AppLocalizations.of(context)!.cls_filtering_search,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui.scale(base: 16, min: 14, max: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandCard(command) {
    final ui = UiScale(context);
    final dateInfo = formatLocalizedDate(command['created_at'] ?? '');
    final parts = dateInfo.split('|');
    final date = parts[0].trim();
    final time = parts[1].trim();

    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ui.scale(base: 16, min: 12, max: 20),
        vertical: ui.scale(base: 8, min: 6, max: 12),
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(
          ui.scale(base: 16, min: 12, max: 20),
        ),
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
          borderRadius: BorderRadius.circular(
            ui.scale(base: 16, min: 12, max: 20),
          ),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.all(ui.scale(base: 20, min: 14, max: 24)),
            child: Row(
              children: [
                // Command Icon
                Container(
                  width: ui.scale(base: 60, min: 48, max: 72),
                  height: ui.scale(base: 60, min: 48, max: 72),
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
                        color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.code,
                      color: Colors.white,
                      size: ui.scale(base: 28, min: 22, max: 34),
                    ),
                  ),
                ),
                SizedBox(width: ui.scale(base: 16, min: 12, max: 20)),

                // Command Info
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${AppLocalizations.of(context)!.cls_user}: ${command['profile']?['user']?['username'] ?? "---"}',
                              style: TextStyle(
                                fontSize: ui.scale(base: 16, min: 14, max: 18),
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                          SizedBox(width: ui.scale(base: 5, min: 4, max: 8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ui.scale(base: 8, min: 6, max: 10),
                              vertical: ui.scale(base: 4, min: 3, max: 6),
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lapisLazuli.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 12, min: 10, max: 14),
                              ),
                              border: Border.all(
                                color: AppColors.lapisLazuli.withValues(
                                  alpha: 0.3,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.cls_command,
                              style: TextStyle(
                                fontSize: ui.scale(base: 12, min: 10, max: 14),
                                color: Color(0xFF00A86B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                      _buildInfoRow(
                        Icons.devices_other,
                        AppLocalizations.of(context)!.cls_device,
                        (command['device']?['name'] ?? "---").toString(),
                      ),
                      SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                      _buildInfoRow(
                        Icons.code,
                        AppLocalizations.of(context)!.cls_command_code,
                        (command['code'] ?? "---").toString(),
                      ),
                      SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                      _buildInfoRow(
                        Icons.access_time,
                        AppLocalizations.of(context)!.cls_date,
                        '$date | $time',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final ui = UiScale(context);
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).textTheme.bodyMedium?.color,
          size: ui.scale(base: 16, min: 14, max: 18),
        ),
        SizedBox(width: ui.scale(base: 6, min: 4, max: 8)),
        Text(
          label,
          style: TextStyle(
            fontSize: ui.scale(base: 13, min: 12, max: 15),
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(width: ui.scale(base: 4, min: 3, max: 6)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: ui.scale(base: 13, min: 12, max: 15),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[100]!, Colors.grey[200]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.code, size: 60, color: Colors.grey[400]),
          ),
          SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.cls_no_commands,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.cls_no_commands_description,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    final ui = UiScale(context);
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ui.scale(base: 16, min: 12, max: 20),
        vertical: ui.scale(base: 8, min: 6, max: 12),
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
            color: AppColors.lapisLazuli.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            ui.scale(base: 16, min: 12, max: 20),
          ),
          onTap: isLoadingMore ? null : () => fetchCommands(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ui.scale(base: 20, min: 14, max: 24),
              vertical: ui.scale(base: 16, min: 12, max: 20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoadingMore)
                  SizedBox(
                    width: ui.scale(base: 20, min: 16, max: 22),
                    height: ui.scale(base: 20, min: 16, max: 22),
                    child: CircularProgressIndicator(
                      strokeWidth: ui.scale(base: 2, min: 1.6, max: 2.4),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_downward,
                    color: Colors.white,
                    size: ui.scale(base: 24, min: 20, max: 28),
                  ),
                SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                Text(
                  isLoadingMore
                      ? AppLocalizations.of(context)!.cls_loading
                      : AppLocalizations.of(context)!.cls_loading_more,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui.scale(base: 16, min: 14, max: 18),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showFilterDialog() {
    final deviceController = TextEditingController(text: filterDevice);
    final usernameController = TextEditingController(text: filterUsername);
    final codeController = TextEditingController(text: filterCode);

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardTheme.color,
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: UiScale(context).scale(base: 16, min: 12, max: 20),
            vertical: UiScale(context).scale(base: 24, min: 16, max: 28),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              UiScale(context).scale(base: 16, min: 12, max: 20),
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.filter_list,
                color: AppColors.lapisLazuli,
                size: UiScale(context).scale(base: 24, min: 20, max: 28),
              ),
              SizedBox(width: UiScale(context).scale(base: 8, min: 6, max: 12)),
              Text(
                AppLocalizations.of(context)!.cls_filter_reports,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterField(
                  controller: deviceController,
                  label: AppLocalizations.of(context)!.cls_name_device,
                  icon: Icons.devices_other,
                ),
                SizedBox(
                  height: UiScale(context).scale(base: 16, min: 12, max: 20),
                ),
                // Hide username filter for level 3 users (they can only see their own reports)
                if (userLevel < 3) ...[
                  _buildFilterField(
                    controller: usernameController,
                    label: AppLocalizations.of(context)!.cls_username,
                    icon: Icons.person,
                  ),
                  SizedBox(
                    height: UiScale(context).scale(base: 16, min: 12, max: 20),
                  ),
                ],
                _buildFilterField(
                  controller: codeController,
                  label: AppLocalizations.of(context)!.cls_command_code,
                  icon: Icons.code,
                ),
                SizedBox(
                  height: UiScale(context).scale(base: 16, min: 12, max: 20),
                ),
                Container(
                  width: double.infinity,
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
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        UiScale(context).scale(base: 12, min: 10, max: 14),
                      ),
                      onTap: () => _pickJalaliDate(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: UiScale(
                            context,
                          ).scale(base: 16, min: 12, max: 20),
                          vertical: UiScale(
                            context,
                          ).scale(base: 12, min: 8, max: 16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: UiScale(
                                context,
                              ).scale(base: 20, min: 16, max: 24),
                            ),
                            SizedBox(
                              width: UiScale(
                                context,
                              ).scale(base: 8, min: 6, max: 12),
                            ),
                            Text(
                              AppLocalizations.of(context)!.cls_choosing_date,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (filterDate != null) ...[
                  SizedBox(
                    height: UiScale(context).scale(base: 12, min: 10, max: 16),
                  ),
                  Container(
                    padding: EdgeInsets.all(
                      UiScale(context).scale(base: 12, min: 10, max: 16),
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
                        UiScale(context).scale(base: 16, min: 12, max: 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: UiScale(
                            context,
                          ).scale(base: 16, min: 14, max: 18),
                        ),
                        SizedBox(
                          width: UiScale(
                            context,
                          ).scale(base: 8, min: 6, max: 12),
                        ),
                        Flexible(
                          child: Text(
                            '${AppLocalizations.of(context)!.cls_choosed_date}: ${filterDateDisplay ?? filterDate}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  filterDevice = null;
                  filterUsername = null;
                  filterCode = null;
                  filterDate = null;
                  filterDateDisplay = null;
                });
                fetchCommands(reset: true);
              },
              child: Text(AppLocalizations.of(context)!.cls_clear),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.lapisLazuli,
                    AppColors.lapisLazuli.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      filterDevice = deviceController.text;
                      filterUsername = usernameController.text;
                      filterCode = codeController.text;
                    });
                    fetchCommands(reset: true);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      AppLocalizations.of(context)!.cls_apply_filter,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.lapisLazuli),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Future<void> _pickJalaliDate() async {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    if (isEnglish) {
      final DateTime nowMiladi = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: nowMiladi,
        firstDate: DateTime(2000, 1, 1),
        lastDate: DateTime(2100, 12, 31),
        builder: (ctx, child) {
          return Directionality(
            textDirection: Localizations.localeOf(ctx).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (picked != null) {
        setState(() {
          filterDate =
              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          filterDateDisplay =
              "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
        });
      }
      return;
    }

    final now = Jalali.now();
    Jalali? selectedDate = now;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: Localizations.localeOf(context).languageCode == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, dialogSetState) {
              return AlertDialog(
                backgroundColor: Theme.of(context).cardTheme.color,
                surfaceTintColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: UiScale(
                    context,
                  ).scale(base: 16, min: 12, max: 20),
                  vertical: UiScale(context).scale(base: 24, min: 16, max: 28),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UiScale(context).scale(base: 16, min: 12, max: 20),
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.cls_select_date_shamsi,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: UiScale(
                      context,
                    ).scale(base: 18, min: 16, max: 20),
                  ),
                ),
                content: SizedBox(
                  width: UiScale(
                    context,
                  ).scale(base: screenWidth * 0.9, min: 260, max: 520),
                  height: UiScale(
                    context,
                  ).scale(base: screenHeight * 0.45, min: 260, max: 520),
                  child: JalaliDatePickerWidget(
                    initialDate: selectedDate!,
                    onDateSelected: (date) {
                      selectedDate = date;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLocalizations.of(context)!.cls_cancel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedDate != null) {
                        final miladi = selectedDate!.toDateTime();
                        setState(() {
                          filterDate =
                              "${miladi.year}-${miladi.month.toString().padLeft(2, '0')}-${miladi.day.toString().padLeft(2, '0')}";
                          filterDateDisplay =
                              "${selectedDate!.year}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.day.toString().padLeft(2, '0')}";
                        });
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lapisLazuli,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UiScale(context).scale(base: 10, min: 8, max: 12),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: UiScale(
                          context,
                        ).scale(base: 16, min: 12, max: 20),
                        vertical: UiScale(
                          context,
                        ).scale(base: 10, min: 8, max: 14),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.cls_submit,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
              duration: const Duration(seconds: 2),
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
                  horizontal: UiScale(
                    context,
                  ).scale(base: 16, min: 12, max: 20),
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
                          onPressed: () {},
                        ),
                      ],
                    ),
                    // Center - Text
                    Flexible(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.cls_title,
                          style: theme.appBarTheme.titleTextStyle,
                        ),
                      ),
                    ),
                    // Right side - Logo
                    Row(
                      children: [
                        Image.asset(
                          'assets/logouzita.png',
                          height: UiScale(
                            context,
                          ).scale(base: screenHeight * 0.08, min: 28, max: 56),
                          width: UiScale(
                            context,
                          ).scale(base: screenHeight * 0.08, min: 28, max: 56),
                        ),
                      ],
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
          refreshUserData: fetchCommands,
          logout: () async {
            final prefs = await SharedPreferences.getInstance();
            final saved = prefs.getString('saved_username');
            final preservedLanguage = prefs.getString('selectedLanguage');
            await prefs.clear();
            if (saved != null && saved.isNotEmpty) {
              await prefs.setString('saved_username', saved);
            }
            if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
              await prefs.setString('selectedLanguage', preservedLanguage);
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
                  // Header and filter (shrink-wrapped)
                  Directionality(
                    textDirection:
                        Localizations.localeOf(context).languageCode == 'en'
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Compact header section with command count
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(
                            horizontal: UiScale(
                              context,
                            ).scale(base: 16, min: 12, max: 20),
                            vertical: UiScale(
                              context,
                            ).scale(base: 8, min: 6, max: 12),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: UiScale(
                              context,
                            ).scale(base: 16, min: 12, max: 20),
                            vertical: UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16),
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
                              UiScale(
                                context,
                              ).scale(base: 12, min: 10, max: 14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lapisLazuli.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: UiScale(
                                  context,
                                ).scale(base: 40, min: 32, max: 48),
                                height: UiScale(
                                  context,
                                ).scale(base: 40, min: 32, max: 48),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(
                                    UiScale(
                                      context,
                                    ).scale(base: 10, min: 8, max: 12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.terminal,
                                  color: Colors.white,
                                  size: UiScale(
                                    context,
                                  ).scale(base: 20, min: 16, max: 24),
                                ),
                              ),
                              SizedBox(
                                width: UiScale(
                                  context,
                                ).scale(base: 12, min: 8, max: 16),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.cls_commands,
                                          style: TextStyle(
                                            fontSize: UiScale(
                                              context,
                                            ).scale(base: 14, min: 12, max: 16),
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        isLoading
                                            ? Row(
                                                children: [
                                                  SizedBox(
                                                    width: UiScale(context)
                                                        .scale(
                                                          base: 14,
                                                          min: 12,
                                                          max: 16,
                                                        ),
                                                    height: UiScale(context)
                                                        .scale(
                                                          base: 14,
                                                          min: 12,
                                                          max: 16,
                                                        ),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth:
                                                          UiScale(
                                                            context,
                                                          ).scale(
                                                            base: 2,
                                                            min: 1.6,
                                                            max: 2.4,
                                                          ),
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '${commands.length} ${AppLocalizations.of(context)!.cls_command}',
                                                style: TextStyle(
                                                  fontSize: UiScale(context)
                                                      .scale(
                                                        base: 18,
                                                        min: 16,
                                                        max: 20,
                                                      ),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ],
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: UiScale(
                                          context,
                                        ).scale(base: 8, min: 6, max: 10),
                                        vertical: UiScale(
                                          context,
                                        ).scale(base: 4, min: 3, max: 6),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          UiScale(
                                            context,
                                          ).scale(base: 8, min: 6, max: 10),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            color: Colors.white,
                                            size: UiScale(
                                              context,
                                            ).scale(base: 16, min: 14, max: 18),
                                          ),
                                          SizedBox(
                                            width: UiScale(
                                              context,
                                            ).scale(base: 4, min: 3, max: 6),
                                          ),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.cls_observe,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: UiScale(context).scale(
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
                        // Filter button
                        _buildFilterButton(),
                      ],
                    ),
                  ),
                  // Command list (takes all available space)
                  Flexible(
                    child: Directionality(
                      textDirection:
                          Localizations.localeOf(context).languageCode == 'en'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      child: isLoading && commands.isEmpty
                          ? Center(
                              child: SharedLoading(
                                title: AppLocalizations.of(
                                  context,
                                )!.cls_loading_reports,
                              ),
                            )
                          : commands.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => fetchCommands(reset: true),
                              color: AppColors.lapisLazuli,
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                itemCount: commands.length + 1,
                                itemBuilder: (context, index) {
                                  if (index < commands.length) {
                                    return _buildCommandCard(commands[index]);
                                  } else if (nextCursor != null) {
                                    return _buildLoadMoreButton();
                                  } else {
                                    return SizedBox();
                                  }
                                },
                              ),
                            ),
                    ),
                  ),
                  // Moved bottom navigation to Scaffold.bottomNavigationBar
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
                Icons.analytics_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),

            SizedBox(height: 24),

            // Title
            Text(
              AppLocalizations.of(context)!.cls_waiting_for_activation,
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
              )!.cls_waiting_for_activation_description,
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
                        AppLocalizations.of(context)!.cls_contact_admin,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.cls_contact_admin_button,
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

class JalaliDatePickerWidget extends StatefulWidget {
  final Jalali initialDate;
  final Function(Jalali) onDateSelected;

  const JalaliDatePickerWidget({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<JalaliDatePickerWidget> createState() => _JalaliDatePickerWidgetState();
}

class _JalaliDatePickerWidgetState extends State<JalaliDatePickerWidget> {
  late Jalali currentDate;
  late Jalali selectedDate;

  final List<String> persianMonths = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  final List<String> persianWeekDays = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  @override
  void initState() {
    super.initState();
    currentDate = widget.initialDate;
    selectedDate = widget.initialDate;
  }

  void _previousMonth() {
    setState(() {
      if (currentDate.month == 1) {
        currentDate = Jalali(currentDate.year - 1, 12, 1);
      } else {
        currentDate = Jalali(currentDate.year, currentDate.month - 1, 1);
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (currentDate.month == 12) {
        currentDate = Jalali(currentDate.year + 1, 1, 1);
      } else {
        currentDate = Jalali(currentDate.year, currentDate.month + 1, 1);
      }
    });
  }

  List<Jalali?> _getDaysInMonth() {
    // Calculate days in month for Jalali calendar
    int daysInMonth;
    if (currentDate.month <= 6) {
      daysInMonth = 31;
    } else if (currentDate.month <= 11) {
      daysInMonth = 30;
    } else {
      // Esfand (12th month) - check if it's a leap year
      // Jalali leap year calculation: year % 33 == 1, 5, 9, 13, 17, 22, 26, 30
      final year = currentDate.year;
      final leapYearRemainders = [1, 5, 9, 13, 17, 22, 26, 30];
      final isLeapYear = leapYearRemainders.contains(year % 33);
      daysInMonth = isLeapYear ? 30 : 29;
    }

    final firstDayOfMonth = Jalali(currentDate.year, currentDate.month, 1);
    // Calculate weekday (0 = Saturday, 1 = Sunday, ..., 6 = Friday)
    final firstDayWeekday = (firstDayOfMonth.toDateTime().weekday + 1) % 7;

    List<Jalali?> days = [];

    // Add empty days for the beginning of the month
    for (int i = 0; i < firstDayWeekday; i++) {
      days.add(null);
    }

    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(Jalali(currentDate.year, currentDate.month, day));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();

    return Column(
      children: [
        // Header with month/year and navigation
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: Icon(Icons.chevron_left),
                iconSize: 24,
                color: AppColors.lapisLazuli,
              ),
              Text(
                '${persianMonths[currentDate.month - 1]} ${currentDate.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lapisLazuli,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: Icon(Icons.chevron_right),
                iconSize: 24,
                color: AppColors.lapisLazuli,
              ),
            ],
          ),
        ),

        // Week days header
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: persianWeekDays
                .map(
                  (day) => Expanded(
                    child: Container(
                      height: 36,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];

              if (day == null) {
                return Container();
              }

              final isSelected =
                  selectedDate.year == day.year &&
                  selectedDate.month == day.month &&
                  selectedDate.day == day.day;

              final isToday =
                  Jalali.now().year == day.year &&
                  Jalali.now().month == day.month &&
                  Jalali.now().day == day.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = day;
                  });
                  widget.onDateSelected(day);
                },
                child: Container(
                  margin: EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.lapisLazuli
                        : isToday
                        ? AppColors.lapisLazuli.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.lapisLazuli, width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? AppColors.lapisLazuli
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
