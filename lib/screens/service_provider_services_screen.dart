import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'dart:convert';
import '../services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';

class ServiceProviderServicesScreen extends StatefulWidget {
  const ServiceProviderServicesScreen({super.key});

  @override
  State<ServiceProviderServicesScreen> createState() =>
      _ServiceProviderServicesScreenState();
}

class _ServiceProviderServicesScreenState
    extends State<ServiceProviderServicesScreen>
    with SingleTickerProviderStateMixin {
  List completedServices = [];
  List pendingServices = [];
  bool isLoading = true;
  int selectedNavIndex = 2; // Services tab index for level 2 users
  int userLevel = 2;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 2;
    });
    fetchServices();
  }

  Future<void> fetchServices() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();

      // TODO: Replace with actual API endpoint when provided
      // For now, using placeholder endpoints
      final completedResponse = await http.get(
        Uri.parse('$baseUrl5/serviceprovider/completed/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      final pendingResponse = await http.get(
        Uri.parse('$baseUrl5/serviceprovider/pending/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (completedResponse.statusCode == 200) {
        final body = utf8.decode(completedResponse.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is Map && data['error'] != null) {
          // Handle error but don't show snackbar for now (API not ready)
          setState(() {
            completedServices = [];
          });
        } else {
          setState(() {
            completedServices = (data is List) ? data : [];
          });
        }
      } else {
        setState(() {
          completedServices = [];
        });
      }

      if (pendingResponse.statusCode == 200) {
        final body = utf8.decode(pendingResponse.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is Map && data['error'] != null) {
          // Handle error but don't show snackbar for now (API not ready)
          setState(() {
            pendingServices = [];
          });
        } else {
          setState(() {
            pendingServices = (data is List) ? data : [];
          });
        }
      } else {
        setState(() {
          pendingServices = [];
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        completedServices = [];
        pendingServices = [];
      });
      // Don't show error snackbar for now since API is not ready
    }
  }

  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        // Miladi (Gregorian)
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        // Shamsi (Jalali)
        final j = Jalali.fromDateTime(date);
        return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateString;
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
      case 2: // Services - already here
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 48),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui.scale(base: 16, min: 12, max: 20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side - Title
                      Text(
                        localizations.sps_services,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      // Right - Logo
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
                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.lapisLazuli,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  indicatorColor: AppColors.lapisLazuli,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      text: localizations.sps_pending_services,
                      icon: Icon(Icons.pending_actions),
                    ),
                    Tab(
                      text: localizations.sps_completed_services,
                      icon: Icon(Icons.check_circle_outline),
                    ),
                  ],
                ),
              ],
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
        child: TabBarView(
          controller: _tabController,
          children: [
            // Pending Services Tab
            _buildServicesList(pendingServices, true),
            // Completed Services Tab
            _buildServicesList(completedServices, false),
          ],
        ),
      ),
      bottomNavigationBar: SharedBottomNavigation(
        selectedIndex: selectedNavIndex,
        userLevel: userLevel,
        onItemTapped: _onNavItemTapped,
      ),
    );
  }

  Widget _buildServicesList(List services, bool isPending) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return Center(
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
      );
    }

    if (services.isEmpty) {
      return _buildEmptyState(isPending);
    }

    return RefreshIndicator(
      onRefresh: fetchServices,
      color: AppColors.lapisLazuli,
      child: ListView.builder(
        padding: EdgeInsets.only(
          left: kSpacing,
          right: kSpacing,
          top: kSpacing,
          bottom: kSpacing + MediaQuery.of(context).padding.bottom + 20,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          final title = service['title'] ?? service['service_title'] ?? '---';
          final hazine =
              service['hazine']?.toString() ??
              service['cost']?.toString() ??
              '0';
          final createdAt = service['created_at'] ?? '';
          final status = service['status'] ?? 'open';

          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/service-provider-service-detail',
                arguments: service,
              );
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppColors.lapisLazuli.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                padding: EdgeInsets.all(16),
                child: Row(
                  textDirection: Directionality.of(context),
                  children: [
                    // Status badge
                    Container(
                      padding: EdgeInsets.symmetric(
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
                    SizedBox(width: 12),
                    // Service info
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: 6),
                          Row(
                            textDirection: Directionality.of(context),
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 14,
                                color: AppColors.maroon,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '$hazine ${localizations.sls_tooman}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.maroon,
                                ),
                                textDirection: Directionality.of(context),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: AppColors.iranianGray,
                              ),
                              SizedBox(width: 4),
                              Text(
                                formatDate(createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                ),
                                textDirection: Directionality.of(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      textDirection:
                          Directionality.of(context) == TextDirection.rtl
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
    );
  }

  Widget _buildEmptyState(bool isPending) {
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
                isPending ? Icons.pending_actions : Icons.check_circle_outline,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              isPending
                  ? localizations.sps_no_pending_services
                  : localizations.sps_no_completed_services,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              isPending
                  ? localizations.sps_no_pending_services_description
                  : localizations.sps_no_completed_services_description,
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
      default:
        return Colors.orange;
    }
  }
}
