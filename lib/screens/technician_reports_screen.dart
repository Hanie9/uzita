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
import 'package:uzita/utils/keyboard_dismiss.dart';
import 'package:uzita/utils/paged_results.dart';
import 'package:uzita/utils/technician_task_utils.dart';
import 'package:uzita/widgets/technician_task_filter_menu.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/widgets/tappable_phone.dart';
import 'package:uzita/widgets/task_accounting_sheet.dart';

class TechnicianReportsScreen extends StatefulWidget {
  const TechnicianReportsScreen({super.key});

  @override
  State<TechnicianReportsScreen> createState() =>
      _TechnicianReportsScreenState();
}

class _TechnicianReportsScreenState extends State<TechnicianReportsScreen>
    with WidgetsBindingObserver {
  List tasks = [];
  bool isLoading = true;
  bool _isLoadingMore = false;
  String? _nextPageUrl;
  int _requestGen = 0;
  int selectedNavIndex = 2; // Reports tab index for technician users
  int userLevel = 2;
  String organType = '';
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  void Function() _cancelKeyboardDismiss = () {};
  double _keyboardInset = 0;
  String _reportSearchQuery = '';
  String _reportStatusFilter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cancelKeyboardDismiss = bindKeyboardDismiss(_clearSearchFocus);
    _scrollController.addListener(_onScroll);
    _loadUserData();
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final double inset = views.first.viewInsets.bottom;
    if (_keyboardInset > 0 && inset == 0) {
      _clearSearchFocus();
    }
    _keyboardInset = inset;
  }

  void _clearSearchFocus() {
    if (_searchFocus.hasFocus) {
      _searchFocus.unfocus();
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isModir = prefs.getBool('modir') ?? false;
    if (!mounted) return;
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

  Future<void> fetchTasks({bool reset = true}) async {
    if (!mounted) return;
    if (!reset && (_isLoadingMore || isLoading || _nextPageUrl == null)) {
      return;
    }

    final int gen = reset ? ++_requestGen : _requestGen;
    final String? pageUrl = reset ? null : _nextPageUrl;
    setState(() {
      if (reset) {
        isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted || gen != _requestGen) return;
        setState(() {
          isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      await SessionManager().onNetworkRequest();
      if (!mounted || gen != _requestGen) return;

      final String url =
          pageUrl ??
          '$_listEndpoint?ts=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );
      if (!mounted || gen != _requestGen) return;

      if (response.statusCode != 200) {
        setState(() {
          if (reset) {
            tasks = [];
            _nextPageUrl = null;
          }
          isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map && data['error'] != null) {
        setState(() {
          if (reset) {
            tasks = [];
            _nextPageUrl = null;
          }
          isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      final ReportPagePayload page = parseReportPage(
        data,
        listEndpoint: _listEndpoint,
      );
      final List<Map<String, dynamic>> incoming = page.results
          .whereType<Map>()
          .map(
            (dynamic item) =>
                normalizeTechnicianTask(Map<String, dynamic>.from(item)),
          )
          .toList();
      final String? nextUrl = page.nextUrl == pageUrl ? null : page.nextUrl;
      setState(() {
        tasks = _sortReportsForRole(
          reset ? incoming : appendUniqueReports(tasks, incoming),
        );
        _nextPageUrl = nextUrl;
        isLoading = false;
        _isLoadingMore = false;
      });
      _continueIfNeeded();
    } catch (e) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        isLoading = false;
        _isLoadingMore = false;
        if (reset) {
          tasks = [];
          _nextPageUrl = null;
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelKeyboardDismiss();
    _scrollController.dispose();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || isLoading || _isLoadingMore || _nextPageUrl == null) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      fetchTasks(reset: false);
    }
  }

  void _scrollResultsToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.offset <= 0) return;
      _scrollController.jumpTo(0);
    });
  }

  String get _listEndpoint => '$baseUrl5/technician/reports';

  void _continueIfNeeded() {
    if (!mounted || isLoading || _isLoadingMore || _nextPageUrl == null) return;
    final bool searching = _reportSearchQuery.trim().isNotEmpty;
    if (searching || _filteredReportsForSearch().isEmpty) {
      fetchTasks(reset: false);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoading || _isLoadingMore || _nextPageUrl == null) {
        return;
      }
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 48) {
        fetchTasks(reset: false);
      }
    });
  }

  String _buildTaskSearchHaystack(Map<String, dynamic> task) {
    final String customerFirst =
        task['customer_first_name']?.toString().trim() ?? '';
    final String customerLast =
        task['customer_last_name']?.toString().trim() ?? '';
    final String customerName = task['customer_name']?.toString().trim() ?? '';
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

  List<Map<String, dynamic>> _filteredReportsForSearch() {
    final List<Map<String, dynamic>> allReports = tasks
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((task) => matchesReportStatusFilter(task, _reportStatusFilter))
        .toList();

    final String query = _reportSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return allReports;

    return allReports
        .where((task) => !isTechnicianUnassigned(task))
        .where((task) => _buildTaskSearchHaystack(task).contains(query))
        .toList();
  }

  List<TechnicianTaskFilterOption> _reportFilterOptions(
    AppLocalizations localizations,
  ) {
    return <TechnicianTaskFilterOption>[
      TechnicianTaskFilterOption(
        value: 'active',
        label: localizations.tech_filter_active_reports,
      ),
      TechnicianTaskFilterOption(
        value: 'canceled',
        label: localizations.tech_filter_canceled_reports,
      ),
    ];
  }

  Widget _buildSearchAndFilter(AppLocalizations localizations) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<TechnicianTaskFilterOption> options = _reportFilterOptions(
      localizations,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.lapisLazuli.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onTapOutside: (_) => _clearSearchFocus(),
            onEditingComplete: _clearSearchFocus,
            onChanged: (String value) {
              setState(() => _reportSearchQuery = value);
              _scrollResultsToTop();
              _continueIfNeeded();
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: localizations.tech_mission_search_hint,
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.lapisLazuli,
                size: 22,
              ),
              suffixIcon: _reportSearchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      tooltip: localizations.cls_filtering_search,
                      onPressed: () {
                        _searchController.clear();
                        _clearSearchFocus();
                        setState(() => _reportSearchQuery = '');
                        _scrollResultsToTop();
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.lapisLazuli.withValues(alpha: 0.1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.lapisLazuli.withValues(
                  alpha: isDark ? 0.16 : 0.08,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: options.map((TechnicianTaskFilterOption option) {
                  final bool selected = option.value == _reportStatusFilter;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: selected
                            ? AppColors.lapisLazuli
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            _clearSearchFocus();
                            if (selected) return;
                            setState(() => _reportStatusFilter = option.value);
                            _continueIfNeeded();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              option.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isTechnicianOrgManager =>
      userLevel == 1 && organType == 'technician';

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

  List<Map<String, dynamic>> _sortReportsForRole(
    List<Map<String, dynamic>> source,
  ) {
    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(
      source,
    );
    sorted.sort((a, b) {
      final String ra = _isTechnicianOrgManager
          ? (a['created_at'] ?? '').toString()
          : _assignedToTechnicianRaw(a);
      final String rb = _isTechnicianOrgManager
          ? (b['created_at'] ?? '').toString()
          : _assignedToTechnicianRaw(b);
      final DateTime da = _parseSortableDate(ra);
      final DateTime db = _parseSortableDate(rb);
      return db.compareTo(da);
    });
    return sorted;
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
    final List<Map<String, dynamic>> visibleReports =
        _filteredReportsForSearch();

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
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              '${visibleReports.length} ${localizations.nav_report}',
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
                                ),
                                if (_isTechnicianOrgManager) ...[
                                  const SizedBox(width: 8),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.lapisLazuli,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => showTaskAccountingSheet(
                                      context,
                                      TaskAccountingKind.technician,
                                    ),
                                    child: Text(
                                      localizations.accounting_title,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui.scale(base: 16, min: 12, max: 20),
                        0,
                        ui.scale(base: 16, min: 12, max: 20),
                        8,
                      ),
                      child: _buildSearchAndFilter(localizations),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: isLoading && tasks.isEmpty
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
                          : visibleReports.isEmpty &&
                                (_isLoadingMore || _nextPageUrl != null)
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.lapisLazuli,
                              ),
                            )
                          : visibleReports.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => fetchTasks(),
                              color: AppColors.lapisLazuli,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: ui.scale(base: 16, min: 12, max: 20),
                                  right: ui.scale(base: 16, min: 12, max: 20),
                                  top: ui.scale(base: 16, min: 12, max: 20),
                                  bottom:
                                      ui.scale(base: 16, min: 12, max: 20) +
                                      MediaQuery.of(context).padding.bottom +
                                      20,
                                ),
                                itemCount:
                                    visibleReports.length +
                                    (_nextPageUrl != null ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= visibleReports.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.lapisLazuli,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final task = visibleReports[index];
                                  final title =
                                      task['title']?.toString() ?? '---';
                                  final status =
                                      task['status']?.toString() ?? 'open';
                                  final dynamic subjectsRaw = task['subjects'];
                                  final String subjectsText =
                                      subjectsRaw is List
                                      ? subjectsRaw
                                            .map((e) => e.toString())
                                            .where((s) => s.isNotEmpty)
                                            .join('، ')
                                      : '';
                                  final String customerFirstName =
                                      task['customer_first_name']
                                          ?.toString()
                                          .trim() ??
                                      '';
                                  final String customerLastName =
                                      task['customer_last_name']
                                          ?.toString()
                                          .trim() ??
                                      '';
                                  final String customerName =
                                      ('$customerFirstName $customerLastName')
                                          .trim()
                                          .isEmpty
                                      ? ((task['customer_name']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ??
                                                false)
                                            ? task['customer_name']
                                                  .toString()
                                                  .trim()
                                            : '---')
                                      : ('$customerFirstName $customerLastName')
                                            .trim();
                                  final String customerPhone =
                                      (task['phone']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ??
                                          false)
                                      ? task['phone'].toString().trim()
                                      : ((task['customer_phone']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ??
                                                false)
                                            ? task['customer_phone']
                                                  .toString()
                                                  .trim()
                                            : '---');
                                  final String customerAddress =
                                      (task['address']
                                              ?.toString()
                                              .trim()
                                              .isNotEmpty ??
                                          false)
                                      ? task['address'].toString().trim()
                                      : '---';
                                  final String subjectText =
                                      subjectsText.isNotEmpty
                                      ? subjectsText
                                      : title;
                                  final String serviceId = taskServiceIdDisplay(
                                    task,
                                  );

                                  return GestureDetector(
                                    onTap: () {
                                      final Map<String, dynamic> taskToSend =
                                          normalizeTechnicianTask(
                                            Map<String, dynamic>.from(task),
                                          );
                                      taskToSend['from_reports_list'] = true;
                                      Navigator.pushNamed(
                                        context,
                                        '/technician-task-detail',
                                        arguments: taskToSend,
                                      );
                                    },
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
                                                  _buildReportInfoRow(
                                                    context: context,
                                                    icon: Icons.tag_outlined,
                                                    label: localizations
                                                        .tech_service_id,
                                                    value: serviceId,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildReportInfoRow(
                                                    context: context,
                                                    icon: Icons.person_outline,
                                                    label: localizations
                                                        .tech_customer_name,
                                                    value: customerName,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildReportInfoRow(
                                                    context: context,
                                                    icon: Icons.phone_outlined,
                                                    label: localizations
                                                        .tech_phone,
                                                    value: customerPhone,
                                                    isPhone: true,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildReportInfoRow(
                                                    context: context,
                                                    icon: Icons
                                                        .location_on_outlined,
                                                    label: localizations
                                                        .tech_address,
                                                    value: customerAddress,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildReportInfoRow(
                                                    context: context,
                                                    icon: Icons.label_outline,
                                                    label: localizations
                                                        .sss_subject,
                                                    value: subjectText.isEmpty
                                                        ? '---'
                                                        : subjectText,
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

  Widget _buildReportInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
    bool isPhone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: Directionality.of(context),
      children: [
        Icon(icon, size: 14, color: AppColors.iranianGray),
        const SizedBox(width: 4),
        Expanded(
          child: isPhone
              ? Row(
                  textDirection: Directionality.of(context),
                  children: [
                    Text(
                      '$label: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    Expanded(
                      child: TappablePhone(
                        phone: value,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: maxLines,
                      ),
                    ),
                  ],
                )
              : Text(
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
    final bool isCanceledFilter = _reportStatusFilter == 'canceled';
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
                isCanceledFilter
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              isCanceledFilter
                  ? localizations.tech_no_canceled_reports
                  : localizations.tech_no_completed_tasks,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isCanceledFilter
                  ? localizations.tech_no_canceled_reports_description
                  : localizations.tech_no_completed_tasks_description,
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
