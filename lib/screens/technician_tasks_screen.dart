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
import 'package:uzita/utils/technician_task_utils.dart';
import 'package:uzita/widgets/technician_task_filter_menu.dart';

class TechnicianTasksScreen extends StatefulWidget {
  const TechnicianTasksScreen({super.key});

  @override
  State<TechnicianTasksScreen> createState() => _TechnicianTasksScreenState();
}

class _TechnicianTasksScreenState extends State<TechnicianTasksScreen> {
  List tasks = [];
  bool isLoading = true;
  int selectedNavIndex = 3; // Missions tab index for technician users
  int userLevel = 2;
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _missionSearchQuery = '';
  String _missionStatusFilter = 'assigned';

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
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      final int logicalLevel = getLogicalUserLevel(userLevel);
      if (isModir && logicalLevel == 1) {
        userRoleTitle =
            AppLocalizations.of(context)!.pro_company_representative;
      } else if (logicalLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (logicalLevel == 2) {
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
        Uri.parse(
          '$baseUrl5/technician/tasks?ts=$ts',
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
        } else {
          final List<dynamic> taskList = extractTechnicianTaskListPayload(data);
          
          // Remove duplicates based on task ID
          final Map<int, dynamic> uniqueTasks = {};
          for (var task in taskList) {
            if (task is Map && task['id'] != null) {
              final id = task['id'] is int
                  ? task['id']
                  : int.tryParse(task['id'].toString());
              if (id != null) {
                uniqueTasks[id] = task;
              }
            }
          }
          
          final List<dynamic> sortedTasks =
              _sortTechnicianTasksByAssignedDate(uniqueTasks.values.toList());
          setState(() {
            tasks = sortedTasks.map((dynamic task) {
              if (task is! Map) return task;
              return normalizeTechnicianTask(
                Map<String, dynamic>.from(task),
              );
            }).toList();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _buildTaskSearchHaystack(Map<String, dynamic> task) {
    final String customerFirst =
        task['customer_first_name']?.toString().trim() ?? '';
    final String customerLast =
        task['customer_last_name']?.toString().trim() ?? '';
    final String customerName =
        task['customer_name']?.toString().trim() ?? '';
    final String phone = task['phone']?.toString().trim() ?? '';
    final String customerPhone =
        task['customer_phone']?.toString().trim() ?? '';
    final String serial = task['serial_number']?.toString().trim() ?? '';
    final String altSerial = task['serial']?.toString().trim() ?? '';
    final String deviceSerial =
        task['device_serial_number']?.toString().trim() ?? '';

    return <String>[
      '$customerFirst $customerLast',
      customerName,
      phone,
      customerPhone,
      serial,
      altSerial,
      deviceSerial,
    ].join(' ').toLowerCase();
  }

  List<Map<String, dynamic>> _filteredTasksForSearch() {
    List<Map<String, dynamic>> base = tasks
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((task) => matchesMissionStatusFilter(task, _missionStatusFilter))
        .toList();

    if (_missionSearchQuery.trim().isEmpty) {
      return base;
    }

    final String query = _missionSearchQuery.trim().toLowerCase();
    return base
        .where((task) => !isTechnicianUnassigned(task))
        .where((task) => _buildTaskSearchHaystack(task).contains(query))
        .toList();
  }

  List<TechnicianTaskFilterOption> _missionFilterOptions(
    AppLocalizations localizations,
  ) {
    return <TechnicianTaskFilterOption>[
      TechnicianTaskFilterOption(
        value: 'assigned',
        label: localizations.tech_filter_assigned_missions,
      ),
      TechnicianTaskFilterOption(
        value: 'suspended',
        label: localizations.tech_filter_suspended_missions,
      ),
    ];
  }

  String _assignedToTechnicianRaw(Map<String, dynamic> task) {
    return (task['date_assigned_to_technician'] ??
            task['data_assigned_to_technician'] ??
            '')
        .toString();
  }

  DateTime _parseSortableDate(String raw) {
    final DateTime? parsed = DateTime.tryParse(raw);
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<dynamic> _sortTechnicianTasksByAssignedDate(List<dynamic> source) {
    final List<dynamic> sorted = List<dynamic>.from(source);
    sorted.sort((a, b) {
      final Map<String, dynamic> ta = a is Map
          ? Map<String, dynamic>.from(a)
          : <String, dynamic>{};
      final Map<String, dynamic> tb = b is Map
          ? Map<String, dynamic>.from(b)
          : <String, dynamic>{};
      final DateTime da = _parseSortableDate(_assignedToTechnicianRaw(ta));
      final DateTime db = _parseSortableDate(_assignedToTechnicianRaw(tb));
      return db.compareTo(da);
    });
    return sorted;
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
      case 2: // Reports
        Navigator.pushReplacementNamed(context, '/technician-reports');
        break;
      case 3: // Missions - already here
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final List<Map<String, dynamic>> visibleTasks = _filteredTasksForSearch();

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
                        localizations.tech_missions,
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
                        Icons.assignment,
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
                                localizations.tech_missions,
                                style: TextStyle(
                                  fontSize: ui.scale(
                                    base: 14,
                                    min: 12,
                                    max: 16,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
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
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '${visibleTasks.length} ${localizations.tech_mission}',
                                      style: TextStyle(
                                        fontSize: ui.scale(
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.scale(base: 16, min: 12, max: 20),
                ),
                child: Container(
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
                          : AppColors.lapisLazuli.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _missionSearchQuery = value);
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: localizations.tech_mission_search_hint,
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.lapisLazuli.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.search,
                          color: AppColors.lapisLazuli,
                          size: 20,
                        ),
                      ),
                      suffixIcon: _missionSearchQuery.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                              tooltip: localizations.cls_filtering_search,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _missionSearchQuery = '');
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.lapisLazuli,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 16, min: 12, max: 20),
                  0,
                  ui.scale(base: 16, min: 12, max: 20),
                  8,
                ),
                child: TechnicianTaskFilterMenu(
                  value: _missionStatusFilter,
                  options: _missionFilterOptions(localizations),
                  onChanged: (String value) {
                    setState(() => _missionStatusFilter = value);
                  },
                ),
              ),
              const SizedBox(height: 8),
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
                        bottom: MediaQuery.of(context).padding.bottom,
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
            : visibleTasks.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: fetchTasks,
                color: AppColors.lapisLazuli,
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: ui.scale(base: 16, min: 12, max: 20),
                    right: ui.scale(base: 16, min: 12, max: 20),
                    top: ui.scale(base: 16, min: 12, max: 20),
                    bottom: ui.scale(base: 16, min: 12, max: 20) +
                        MediaQuery.of(context).padding.bottom +
                        20,
                  ),
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];
                            final taskId =
                                task['id']?.toString() ?? index.toString();
                    final title = task['title']?.toString() ?? '---';
                    final status =
                        (task['status'] ?? 'open').toString().toLowerCase();
                    final dynamic subjectsRaw = task['subjects'];
                    final String subjectsText = subjectsRaw is List
                        ? subjectsRaw
                            .map((e) => e.toString())
                            .where((s) => s.isNotEmpty)
                            .join('، ')
                        : '';
                    final String customerFirstName =
                        task['customer_first_name']?.toString().trim() ?? '';
                    final String customerLastName =
                        task['customer_last_name']?.toString().trim() ?? '';
                    final String customerName =
                        ('$customerFirstName $customerLastName').trim().isEmpty
                        ? ((task['customer_name']?.toString().trim().isNotEmpty ??
                              false)
                              ? task['customer_name'].toString().trim()
                              : '---')
                        : ('$customerFirstName $customerLastName').trim();
                    final String customerPhone =
                        (task['phone']?.toString().trim().isNotEmpty ?? false)
                        ? task['phone'].toString().trim()
                        : ((task['customer_phone']?.toString().trim().isNotEmpty ??
                              false)
                              ? task['customer_phone'].toString().trim()
                              : '---');
                    final String customerAddress =
                        (task['address']?.toString().trim().isNotEmpty ?? false)
                        ? task['address'].toString().trim()
                        : '---';
                    final String subjectText =
                        subjectsText.isNotEmpty ? subjectsText : title;
                    final String serviceId = taskServiceIdDisplay(task);

                    return GestureDetector(
                      key: ValueKey('task_$taskId'),
                      onTap: () {
                        final Map<String, dynamic> taskToSend =
                            normalizeTechnicianTask(
                          Map<String, dynamic>.from(task as Map),
                        );
                        Navigator.pushNamed(
                          context,
                          '/technician-task-detail',
                          arguments: taskToSend,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 6,
                        ),
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
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                ? Colors.grey[700]!
                                        : AppColors.lapisLazuli.withValues(
                                            alpha: 0.08,
                                          ),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            textDirection: Directionality.of(context),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      status,
                                    ).withValues(alpha: 0.3),
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
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                  children: [
                                    _buildMissionInfoRow(
                                      context: context,
                                      icon: Icons.tag_outlined,
                                      label: localizations.tech_service_id,
                                      value: serviceId,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMissionInfoRow(
                                      context: context,
                                      icon: Icons.person_outline,
                                      label: localizations.tech_customer_name,
                                      value: customerName,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMissionInfoRow(
                                      context: context,
                                      icon: Icons.phone_outlined,
                                      label: localizations.tech_phone,
                                      value: customerPhone,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMissionInfoRow(
                                      context: context,
                                      icon: Icons.location_on_outlined,
                                      label: localizations.tech_address,
                                      value: customerAddress,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildMissionInfoRow(
                                      context: context,
                                      icon: Icons.label_outline,
                                      label: localizations.sss_subject,
                                      value:
                                          subjectText.isEmpty ? '---' : subjectText,
                                      maxLines: 2,
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
              AppLocalizations.of(context)!
                  .tls_waiting_for_activation_description,
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

  String _getStatusText(String status, AppLocalizations localizations) {
    switch (status) {
      case 'open':
        return localizations.sps_status_open;
      case 'assigned':
        return localizations.sps_status_assigned;
      case 'suspended':
        return localizations.sps_status_suspended;
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
      case 'suspended':
        return Colors.grey.shade700;
      case 'confirm':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _buildMissionInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: Directionality.of(context),
      children: [
        Icon(
          icon,
          size: 14,
          color: AppColors.iranianGray,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textDirection: Directionality.of(context),
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context)!;
    final bool isSuspendedFilter = _missionStatusFilter == 'suspended';
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
                Icons.assignment_outlined,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              isSuspendedFilter
                  ? localizations.tech_no_suspended_missions
                  : localizations.tech_no_missions,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isSuspendedFilter
                  ? localizations.tech_no_suspended_missions_description
                  : localizations.tech_no_missions_description,
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
