import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/services.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:shamsi_date/shamsi_date.dart';

class TechnicianOrganTasksScreen extends StatefulWidget {
  const TechnicianOrganTasksScreen({super.key});

  @override
  State<TechnicianOrganTasksScreen> createState() =>
      _TechnicianOrganTasksScreenState();
}

class _TechnicianOrganTasksScreenState
    extends State<TechnicianOrganTasksScreen> {
  bool isLoading = true;
  bool isAssigning = false;
  List<Map<String, dynamic>> orgTasks = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> personalTasks = <Map<String, dynamic>>[];
  bool isAuthorized = true;
  int userLevel = 3;
  int selectedNavIndex = 3; // Missions tab for service team lead
  String organType = '';
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserMeta();
    _fetchTasks();
  }

  Future<void> _loadUserMeta() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isModir = prefs.getBool('modir') ?? false;
    final int level = prefs.getInt('level') ?? 3;
    final String name = prefs.getString('username') ?? '';
    final bool active = prefs.getBool('active') ?? true;
    final String organ = (prefs.getString('organ_type') ?? '').toLowerCase();

    if (!mounted) return;

    final AppLocalizations localizations = AppLocalizations.of(context)!;
    String roleTitle;
    final int logicalLevel = getLogicalUserLevel(level);
    if (isModir && logicalLevel == 1 && organ == 'technician') {
      roleTitle = localizations.pro_company_representative;
    } else if (logicalLevel == 1) {
      roleTitle = localizations.pro_admin;
    } else if (logicalLevel == 2 && organ == 'technician') {
      roleTitle = localizations.pro_installer;
    } else if (logicalLevel == 3) {
      roleTitle = localizations.home_driver;
    } else {
      roleTitle = localizations.pro_user;
    }

    setState(() {
      userLevel = level;
      organType = organ;
      username = name;
      userActive = active;
      userRoleTitle = roleTitle;
    });
  }

  Future<void> _fetchTasks() async {
    setState(() {
      isLoading = true;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final int level = prefs.getInt('level') ?? 3;
      final String organType = (prefs.getString('organ_type') ?? '')
          .toLowerCase();

      setState(() {
        userLevel = level;
      });

      final bool allowed = level == 1 && organType == 'technician';
      if (!allowed) {
        if (mounted) {
          setState(() {
            isAuthorized = false;
            isLoading = false;
            orgTasks = <Map<String, dynamic>>[];
            personalTasks = <Map<String, dynamic>>[];
          });
        }
        return;
      }

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          orgTasks = <Map<String, dynamic>>[];
          personalTasks = <Map<String, dynamic>>[];
        });
        return;
      }

      await SessionManager().onNetworkRequest();

      final int ts = DateTime.now().millisecondsSinceEpoch;
      final Uri orgUrl = Uri.parse('$apiBaseUrl/technician-organ/tasks?ts=$ts');
      final Uri personalUrl = Uri.parse('$baseUrl5/technician/tasks?ts=$ts');

      final http.Response orgResponse = await http.get(
        orgUrl,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final http.Response personalResponse = await http.get(
        personalUrl,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;

      List<Map<String, dynamic>> parsedOrgTasks = <Map<String, dynamic>>[];
      if (orgResponse.statusCode == 200) {
        final dynamic data = json.decode(utf8.decode(orgResponse.bodyBytes));
        if (data is List) {
          parsedOrgTasks = data
              .whereType<Map<String, dynamic>>()
              .map<Map<String, dynamic>>(
                (Map<String, dynamic> item) => Map<String, dynamic>.from(item),
              )
              // فقط ماموریت‌هایی که هنوز باز هستند
              .where(
                (Map<String, dynamic> t) =>
                    (t['status'] ?? 'open').toString() == 'open',
              )
              .toList();
        }
      }

      List<Map<String, dynamic>> parsedPersonalTasks = <Map<String, dynamic>>[];
      if (personalResponse.statusCode == 200) {
        final dynamic data = json.decode(
          utf8.decode(personalResponse.bodyBytes),
        );
        List<dynamic> rawList = <dynamic>[];
        if (data is List) {
          rawList = data;
        } else if (data is Map && data['results'] is List) {
          rawList = List<dynamic>.from(data['results'] as List);
        }
        parsedPersonalTasks = rawList
            .whereType<Map<String, dynamic>>()
            .map<Map<String, dynamic>>(
              (Map<String, dynamic> item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      if (mounted) {
        setState(() {
          orgTasks = parsedOrgTasks;
          personalTasks = parsedPersonalTasks;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        orgTasks = <Map<String, dynamic>>[];
        personalTasks = <Map<String, dynamic>>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    // Service team lead navigation: Home (0), Profile (1), Reports (2), Missions (3), Users (4)
    if (userLevel == 1) {
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Reports
          Navigator.pushReplacementNamed(context, '/technician-reports');
          break;
        case 3: // Missions - already here
          break;
        case 4: // Users
          Navigator.pushReplacementNamed(context, '/users');
          break;
      }
    } else {
      // Fallback: behave like normal technician missions (home, profile, reports, missions)
      switch (index) {
        case 0: // Home
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case 1: // Profile
          Navigator.pushReplacementNamed(context, '/profile');
          break;
        case 2: // Reports
          Navigator.pushReplacementNamed(context, '/technician-reports');
          break;
        case 3: // Missions
          Navigator.pushReplacementNamed(context, '/technician-tasks');
          break;
      }
    }
  }

  Future<List<Map<String, String>>> _fetchOrgUsers() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        return <Map<String, String>>[];
      }

      await SessionManager().onNetworkRequest();

      String url = '$apiBaseUrl/listuser/';
      final Map<String, String> queryParams = <String, String>{
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      url += '?${Uri(queryParameters: queryParams).query}';

      final http.Response response = await http.get(
        Uri.parse(url),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (response.statusCode != 200) {
        return <Map<String, String>>[];
      }

      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> rawUsers = <dynamic>[];

      if (data is List) {
        rawUsers = data;
      } else if (data is Map && data['results'] is List) {
        rawUsers = List<dynamic>.from(data['results'] as List);
      } else if (data is Map && data['data'] is List) {
        rawUsers = List<dynamic>.from(data['data'] as List);
      }

      return rawUsers
          .map<Map<String, String>>((dynamic item) {
            final Map<String, dynamic> map = item is Map<String, dynamic>
                ? item
                : <String, dynamic>{};
            final dynamic userData = map['user'] ?? map;
            final Map<String, dynamic> user = userData is Map<String, dynamic>
                ? userData
                : <String, dynamic>{};

            final String username = (user['username'] ?? '').toString().trim();
            final String firstName = (user['first_name'] ?? '')
                .toString()
                .trim();
            final String lastName = (user['last_name'] ?? '').toString().trim();
            String display = username;
            final String fullName = '$firstName $lastName'.trim();
            if (fullName.isNotEmpty) {
              display = '$fullName ($username)';
            }

            return <String, String>{'username': username, 'display': display};
          })
          .where((Map<String, String> u) => u['username']!.isNotEmpty)
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  Future<void> _openAssignmentDialog(Map<String, dynamic> task) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String currentUsername = prefs.getString('username') ?? '';

    // Step 1: show loading dialog while fetching users
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    final List<Map<String, String>> users = await _fetchOrgUsers();

    if (!mounted) return;

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (users.isEmpty) {
      // No users to assign to – show a simple info dialog
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            backgroundColor: Theme.of(ctx).cardTheme.color,
            title: const Text('واگذاری مأموریت'),
            content: const Text('هیچ کاربری برای سازمان شما یافت نشد.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('باشه'),
              ),
            ],
          );
        },
      );
      return;
    }

    String? selectedUsername = currentUsername.trim().isNotEmpty
        ? currentUsername.trim()
        : null;

    // Step 2: show actual assignment dialog with loaded users
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setStateDialog,
              ) {
                return AlertDialog(
                  backgroundColor: Theme.of(context).cardTheme.color,
                  title: const Text(
                    'واگذاری مأموریت',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, String> user = users[index];
                        final String username = user['username']!;
                        final String display = user['display']!;
                        final bool isChecked = selectedUsername == username;

                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: (bool? checked) {
                            setStateDialog(() {
                              if (checked == true) {
                                selectedUsername = username;
                              } else if (selectedUsername == username) {
                                selectedUsername = null;
                              }
                            });
                          },
                          title: Text(display),
                        );
                      },
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('انصراف'),
                    ),
                    ElevatedButton(
                      onPressed: isAssigning || selectedUsername == null
                          ? null
                          : () async {
                              final String username = selectedUsername!.trim();
                              if (username.isEmpty) return;
                              Navigator.of(dialogContext).pop();
                              await _assignTask(task['id'], username);
                            },
                      child: const Text('واگذاری'),
                    ),
                  ],
                );
              },
        );
      },
    );
  }

  Future<void> _assignTask(dynamic id, String username) async {
    setState(() {
      isAssigning = true;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        setState(() {
          isAssigning = false;
        });
        return;
      }

      await SessionManager().onNetworkRequest();

      final Uri url = Uri.parse(
        '$apiBaseUrl/technician-organ/tasks/$id/assignment',
      );

      final http.Response response = await http.post(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(<String, String>{'username': username}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        String msg = AppLocalizations.of(context)!.tech_assignment_success;
        try {
          final dynamic data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map && data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {
          // ignore parse errors, keep default message
        }

        if (mounted) {
          // Remove the assigned task from current orgTasks list immediately
          setState(() {
            orgTasks = orgTasks
                .where(
                  (Map<String, dynamic> t) =>
                      (t['id'] ?? '').toString() != id.toString(),
                )
                .toList();
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        // Then refetch from server to sync with backend
        await _fetchTasks();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در واگذاری مأموریت')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('خطا در ارتباط با سرور')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isAssigning = false;
        });
      }
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool canAssign) {
    final localizations = AppLocalizations.of(context)!;
    final String taskId = (task['id'] ?? '').toString();
    final String title = (task['title'] ?? '---').toString();
    final String? urgency = task['urgency']?.toString();
    final String status = task['status']?.toString() ?? 'open';
    final String createdAt = task['created_at']?.toString() ?? '';
    final dynamic priceValue =
        task['hazine'] ?? task['sayer_hazine'] ?? task['price'];
    final String price = priceValue == null ? '---' : priceValue.toString();

    return GestureDetector(
      onTap: () {
        // For tasks in the organization assignment section (canAssign == true),
        // mark them so that the detail screen only shows basic task info
        // without visit date / report forms.
        final Map<String, dynamic> taskToSend = Map<String, dynamic>.from(task);
        if (canAssign) {
          taskToSend['from_organ_assign_list'] = true;
        }

        Navigator.pushNamed(
          context,
          '/technician-task-detail',
          arguments: taskToSend,
        );
      },
      child: Container(
        key: ValueKey('task_$taskId'),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.2)
                  : AppColors.lapisLazuli.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : AppColors.lapisLazuli.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStatusText(status, localizations),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                  textDirection: Directionality.of(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: Directionality.of(context),
                      children: [
                        const Icon(
                          Icons.title,
                          size: 14,
                          color: AppColors.lapisLazuli,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                            textDirection: Directionality.of(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Urgency
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: Directionality.of(context),
                      children: [
                        const Icon(
                          Icons.priority_high,
                          size: 14,
                          color: AppColors.iranianGray,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            urgency != null
                                ? _getUrgencyText(urgency, localizations)
                                : '---',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.iranianGray,
                            ),
                            textDirection: Directionality.of(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: Directionality.of(context),
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 14,
                          color: AppColors.iranianGray,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            price == '---'
                                ? '---'
                                : '$price ${localizations.sls_tooman}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.iranianGray,
                            ),
                            textDirection: Directionality.of(context),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date
                    if (createdAt.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: Directionality.of(context),
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppColors.iranianGray,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatDate(createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.iranianGray,
                              ),
                              textDirection: Directionality.of(context),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Trailing action: assign button instead of chevron
              if (canAssign)
                TextButton.icon(
                  onPressed: () => _openAssignmentDialog(task),
                  icon: const Icon(
                    Icons.assignment_ind,
                    size: 18,
                    color: AppColors.lapisLazuli,
                  ),
                  label: const Text(
                    'واگذاری',
                    style: TextStyle(
                      color: AppColors.lapisLazuli,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_left,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  textDirection: Directionality.of(context) == TextDirection.rtl
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUrgencyText(String? urgency, AppLocalizations localizations) {
    switch (urgency) {
      case 'normal':
        return localizations.tech_urgency_normal;
      case 'urgent':
        return localizations.tech_urgency_urgent;
      case 'very_urgent':
        return localizations.tech_urgency_very_urgent;
      default:
        return urgency ?? '---';
    }
  }

  String _formatDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        final Jalali j = Jalali.fromDateTime(date);
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
              padding: const EdgeInsets.all(16),
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
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.tech_no_missions,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.tech_no_missions_description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UiScale ui, AppLocalizations localizations) {
    return Container(
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
            offset: const Offset(0, 2),
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
              Icons.assignment,
              color: Colors.white,
              size: ui.scale(base: 20, min: 16, max: 24),
            ),
          ),
          SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.tech_missions,
                  style: TextStyle(
                    fontSize: ui.scale(base: 18, min: 16, max: 20),
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // فقط متن تعداد مأموریت‌ها وابسته به لود شدن است
                // خود کادر آبی همیشه نمایش داده می‌شود.
                isLoading
                    ? SizedBox(
                        width: ui.scale(base: 18, min: 16, max: 20),
                        height: ui.scale(base: 18, min: 16, max: 20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        '${orgTasks.length + personalTasks.length} ${localizations.tech_mission}',
                        style: TextStyle(
                          fontSize: ui.scale(base: 13, min: 12, max: 15),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final ui = UiScale(context);
    final theme = Theme.of(context);
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
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
                  // Left side - menu & notifications
                  Row(
                    children: [
                      Builder(
                        builder: (BuildContext context) => IconButton(
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

                  // Center - title
                  Expanded(
                    child: Center(
                      child: Text(
                        localizations.tech_missions,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                    ),
                  ),

                  // Right side - logo
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
          : !isAuthorized
          ? Center(child: Text(localizations.home_access_denies))
          : Column(
              children: [
                _buildHeader(ui, localizations),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : orgTasks.isEmpty && personalTasks.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _fetchTasks,
                          color: AppColors.lapisLazuli,
                          child: ListView(
                            padding: EdgeInsets.only(
                              left: ui.scale(base: 16, min: 12, max: 20),
                              right: ui.scale(base: 16, min: 12, max: 20),
                              bottom: 12,
                            ),
                            children: [
                              if (orgTasks.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: ui.scale(base: 4, min: 2, max: 6),
                                  ),
                                  child: Text(
                                    localizations
                                        .organ_missions_need_assignment,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ) ??
                                        TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                  ),
                                ),
                                ...orgTasks.map(
                                  (Map<String, dynamic> task) =>
                                      _buildTaskCard(task, true),
                                ),
                              ],
                              if (personalTasks.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: ui.scale(
                                      base: 8,
                                      min: 6,
                                      max: 10,
                                    ),
                                  ),
                                  child: Text(
                                    localizations.my_missions,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ) ??
                                        TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                  ),
                                ),
                                ...personalTasks.map(
                                  (Map<String, dynamic> task) =>
                                      _buildTaskCard(task, false),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
      drawer: SharedAppDrawer(
        username: username,
        userRoleTitle: userRoleTitle,
        userModir: false,
        userLevel: userLevel,
        refreshUserData: _loadUserMeta,
        userActive: userActive,
        logout: () async {
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          final String? saved = prefs.getString('saved_username');
          final String? preservedLanguage = prefs.getString('selectedLanguage');
          final bool? preservedDarkMode = prefs.getBool('darkModeEnabled');
          final double? preservedTextSize = prefs.getDouble('textSize');
          final bool? preservedNotifications = prefs.getBool(
            'notificationsEnabled',
          );

          await prefs.clear();

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

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      ),
      bottomNavigationBar: SharedBottomNavigation(
        selectedIndex: selectedNavIndex,
        userLevel: userLevel,
        onItemTapped: _onNavItemTapped,
        organType: organType,
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
}
