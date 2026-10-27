import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'dart:convert';
import '../services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/keyboard_dismiss.dart';
import 'package:uzita/utils/paged_results.dart';
import 'package:uzita/utils/ui_scale.dart';
// import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/widgets/task_accounting_sheet.dart';

class DriverReportsScreen extends StatefulWidget {
  const DriverReportsScreen({super.key});

  @override
  State<DriverReportsScreen> createState() => _DriverReportsScreenState();
}

class _DriverReportsScreenState extends State<DriverReportsScreen>
    with WidgetsBindingObserver {
  List tasks = [];
  bool isLoading = true;
  bool _isLoadingMore = false;
  String? _nextPageUrl;
  int? _totalCount;
  int _requestGen = 0;
  int selectedNavIndex = 1; // Reports tab index for driver users
  int userLevel = 3;
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  // DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  void Function() _cancelKeyboardDismiss = () {};
  double _keyboardInset = 0;
  String _reportSearchQuery = '';

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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final rawLevel = prefs.getInt('level') ?? 3;
      userLevel = getLogicalUserLevel(rawLevel);
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (userLevel == 3) {
        userRoleTitle = AppLocalizations.of(context)!.home_driver;
      } else {
        userRoleTitle = AppLocalizations.of(context)!.pro_user;
      }
    });
    fetchTasks();
  }

  String get _listEndpoint => '$baseUrl5/transport/report';

  List<dynamic> get _visibleTasks {
    final String query = _reportSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return tasks;
    return tasks.where((dynamic task) {
      if (task is! Map) return false;
      return _searchHaystack(Map<String, dynamic>.from(task)).contains(query);
    }).toList();
  }

  String _searchHaystack(Map<String, dynamic> task) {
    return <String>[
      _partyName(task['customer']),
      _partyName(task['requester']),
      task['mabda']?.toString() ?? '',
      task['maghsad']?.toString() ?? '',
      task['phone']?.toString() ?? '',
      task['description']?.toString() ?? '',
      task['output_number']?.toString() ?? '',
    ].join(' ').toLowerCase();
  }

  void _continueIfNeeded() {
    if (!mounted || isLoading || _isLoadingMore || _nextPageUrl == null) return;
    final bool searching = _reportSearchQuery.trim().isNotEmpty;
    if (searching || _visibleTasks.isEmpty) {
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
            _totalCount = null;
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
            _totalCount = null;
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
      final String? nextUrl = page.nextUrl == pageUrl ? null : page.nextUrl;
      setState(() {
        tasks = reset ? page.results : appendUniqueReports(tasks, page.results);
        _nextPageUrl = nextUrl;
        if (page.totalCount != null) _totalCount = page.totalCount;
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

  // void _onNavItemTapped(int index) {
  //   setState(() {
  //     selectedNavIndex = index;
  //   });

  //   switch (index) {
  //     case 0: // Home
  //       Navigator.pushReplacementNamed(context, '/home');
  //       break;
  //     case 1: // Reports - already here
  //       break;
  //     case 2: // Missions
  //       Navigator.pushReplacementNamed(context, '/driver-missions');
  //       break;
  //     case 3: // Public loads
  //       Navigator.pushReplacementNamed(context, '/transport-public-loads');
  //       break;
  //     case 4: // Profile
  //       Navigator.pushReplacementNamed(context, '/profile');
  //       break;
  //   }
  // }

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

  String getpaymentLabel(String value) {
    final localizations = AppLocalizations.of(context)!;

    switch (value) {
      case 'direct':
        return localizations.trn_direct;
      case 'invoice':
        return localizations.trn_invoice;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      // onPopInvoked: (didPop) {
      //   // if (didPop) return;
      //   // // If drawer is open, close it instead of exiting
      //   // if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      //   //   _scaffoldKey.currentState?.closeDrawer();
      //   //   return;
      //   // }
      //   final now = DateTime.now();
      //   if (_lastBackPressedAt == null ||
      //       now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      //     _lastBackPressedAt = now;
      //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text(localizations.click_again_to_exit),
      //         duration: const Duration(seconds: 2),
      //       ),
      //     );
      //   } else {
      //     SystemNavigator.pop();
      //   }
      // },
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
                      height: MediaQuery.of(context).size.height * 0.08,
                      width: MediaQuery.of(context).size.height * 0.08,
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
                                            base: 14,
                                            min: 12,
                                            max: 16,
                                          ),
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
                                              '${_reportSearchQuery.trim().isEmpty ? (_totalCount ?? tasks.length) : _visibleTasks.length} ${localizations.nav_report}',
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
                                ),
                                const SizedBox(width: 8),
                                _buildAccountingButton(localizations),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        ui.scale(base: 16, min: 12, max: 20),
                        0,
                        ui.scale(base: 16, min: 12, max: 20),
                        8,
                      ),
                      child: _buildSearchField(localizations),
                    ),
                    // Content
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
                          : _visibleTasks.isEmpty &&
                                (_isLoadingMore || _nextPageUrl != null)
                          ? Center(
                              child: CircularProgressIndicator(
                                color: AppColors.lapisLazuli,
                              ),
                            )
                          : _visibleTasks.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => fetchTasks(),
                              color: AppColors.lapisLazuli,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: kSpacing,
                                  right: kSpacing,
                                  top: kSpacing,
                                  bottom:
                                      kSpacing +
                                      MediaQuery.of(context).padding.bottom +
                                      20,
                                ),
                                itemCount:
                                    _visibleTasks.length +
                                    (_nextPageUrl != null ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _visibleTasks.length) {
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
                                  final task = _visibleTasks[index];
                                  final maghsad =
                                      task['maghsad']?.toString() ?? '---';
                                  final mabda =
                                      task['mabda']?.toString() ?? '---';
                                  final status =
                                      task['status']?.toString() ?? 'open';
                                  final createdAt =
                                      task['created_at']?.toString() ?? '';
                                  final paymentType =
                                      task['payment_type']?.toString() ?? '---';
                                  final dynamic feeReceivedValue =
                                      task['fee_received'];
                                  final String feeReceived =
                                      feeReceivedValue == null
                                      ? '---'
                                      : feeReceivedValue.toString();

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/driver-task-detail',
                                        arguments: {
                                          'task': task,
                                          'isReport': true,
                                        },
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
                                                  // Origin --> Destination
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    textDirection:
                                                        Directionality.of(
                                                          context,
                                                        ),
                                                    children: [
                                                      Icon(
                                                        Icons.location_city,
                                                        size: 14,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          mabda,
                                                          style: TextStyle(
                                                            fontSize: 13,
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
                                                      SizedBox(width: 6),
                                                      Icon(
                                                        Icons.arrow_forward,
                                                        size: 16,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: AppColors
                                                            .lapisLazuli,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          maghsad,
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
                                                  SizedBox(height: 6),
                                                  _buildPartyRow(
                                                    context,
                                                    Icons.person_outline,
                                                    '${localizations.trn_customer}: ${_partyName(task['customer'])}',
                                                  ),
                                                  SizedBox(height: 4),
                                                  _buildPartyRow(
                                                    context,
                                                    Icons
                                                        .assignment_ind_outlined,
                                                    '${localizations.driver_requester}: ${_partyName(task['requester'])}',
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Payment type
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    textDirection:
                                                        Directionality.of(
                                                          context,
                                                        ),
                                                    children: [
                                                      Icon(
                                                        Icons.payment,
                                                        size: 14,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          getpaymentLabel(
                                                            paymentType,
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
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Fee received
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
                                                          feeReceived == '---'
                                                              ? '---'
                                                              : '$feeReceived ${localizations.sls_tooman}',
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
        // bottomNavigationBar: SharedBottomNavigation(
        //   selectedIndex: selectedNavIndex,
        //   userLevel: userLevel,
        //   onItemTapped: _onNavItemTapped,
        // ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations localizations) {
    return Container(
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
          hintText: localizations.driver_report_search_hint,
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
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountingButton(AppLocalizations localizations) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lapisLazuli,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () =>
          showTaskAccountingSheet(context, TaskAccountingKind.driver),
      child: Text(
        localizations.accounting_title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _partyName(dynamic value) {
    if (value is Map) {
      for (final String key in <String>[
        'name',
        'full_name',
        'title',
        'username',
      ]) {
        final String text = value[key]?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '---';
    }
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? '---' : text;
  }

  Widget _buildPartyRow(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: Directionality.of(context),
      children: [
        Icon(icon, size: 14, color: AppColors.iranianGray),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.iranianGray),
            textDirection: Directionality.of(context),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
              localizations.driver_no_completed_loads,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              localizations.driver_no_completed_loads_description,
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
