import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/screens/login_screen.dart';

class DriverPublicLoadsScreen extends StatefulWidget {
  const DriverPublicLoadsScreen({super.key});

  @override
  State<DriverPublicLoadsScreen> createState() =>
      _DriverPublicLoadsScreenState();
}

class _DriverPublicLoadsScreenState extends State<DriverPublicLoadsScreen> {
  List<dynamic> loads = [];
  bool isLoading = true;
  int selectedNavIndex = 3; // Public loads tab index for level 5 users
  int userLevel = 5;
  String username = '';
  String userRoleTitle = '';
  bool userActive = true;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 5;
      username = prefs.getString('username') ?? '';
      userActive = prefs.getBool('active') ?? true;
      if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.pro_admin;
      } else if (userLevel == 5) {
        userRoleTitle = AppLocalizations.of(context)!.home_driver;
      } else {
        userRoleTitle = AppLocalizations.of(context)!.pro_user;
      }
    });
    _fetchLoads();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // Reports
        Navigator.pushReplacementNamed(context, '/driver-reports');
        break;
      case 2: // Missions
        Navigator.pushReplacementNamed(context, '/driver-missions');
        break;
      case 3: // Public loads - already here
        break;
      case 4: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Future<void> _fetchLoads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl5/transport/public'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);

        List<dynamic> all = [];
        if (data is List) {
          all = data;
        } else if (data is Map && data['results'] is List) {
          all = data['results'] as List<dynamic>;
        }

        setState(() {
          loads = all;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectLoad(int loadId) async {
    final localizations = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.error_token_missing),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );

    try {
      await SessionManager().onNetworkRequest();
      final response = await http.post(
        Uri.parse('$baseUrl5/transport/public/$loadId/select'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: false).pop(); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);
        final message =
            (data['message'] ?? localizations.driver_select_load_success)
                .toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        // Refresh the list
        await _fetchLoads();
      } else {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);
        final errorMessage =
            (data['message'] ??
                    data['error'] ??
                    localizations.driver_select_load_error)
                .toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : localizations.driver_select_load_error,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: false).canPop()) {
        Navigator.of(
          context,
          rootNavigator: false,
        ).pop(); // Close loading dialog
      }

      final localizations = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.error_network),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final localizations = AppLocalizations.of(context)!;

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
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.scale(base: 16, min: 12, max: 20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    Expanded(
                      child: Center(
                        child: Text(
                          localizations.nav_public_loads,
                          style: Theme.of(context).appBarTheme.titleTextStyle
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
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
        body: Directionality(
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
                        Icons.inventory_2,
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
                                localizations.nav_public_loads,
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
                                      '${loads.length} ${localizations.nav_public_loads}',
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
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.lapisLazuli,
                          ),
                          strokeWidth: 3,
                        ),
                      )
                    : loads.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchLoads,
                        color: AppColors.lapisLazuli,
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            left: kSpacing,
                            right: kSpacing,
                            top: kSpacing,
                            bottom:
                                kSpacing +
                                MediaQuery.of(context).padding.bottom +
                                20,
                          ),
                          itemCount: loads.length,
                          itemBuilder: (context, index) {
                            final load = loads[index] as Map;
                            final loadId = load['id'];
                            final String maghsad = (load['maghsad'] ?? '---')
                                .toString();
                            final String mabda = (load['mabda'] ?? '---')
                                .toString();
                            final String phone = (load['phone'] ?? '---')
                                .toString();
                            final dynamic priceTransportValue =
                                load['price_transport'];
                            final String priceTransport =
                                priceTransportValue == null
                                ? '---'
                                : priceTransportValue.toString();
                            final dynamic vaznValue = load['vazn'];
                            final String vazn = vaznValue == null
                                ? '---'
                                : vaznValue.toString();
                            final bool bime = load['bime'] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
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
                                    offset: const Offset(0, 2),
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
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_shipping_outlined,
                                          color: AppColors.lapisLazuli,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Origin -> Destination
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_city,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      mabda,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.arrow_forward,
                                                    size: 16,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Icon(
                                                    Icons.location_on,
                                                    size: 14,
                                                    color:
                                                        AppColors.lapisLazuli,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      maghsad,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Phone
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      phone,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Price
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.attach_money,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      priceTransport == '---'
                                                          ? '---'
                                                          : '$priceTransport ${localizations.sls_tooman}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              // Weight and Insurance
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.scale,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${localizations.driver_weight}: $vazn',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.iranianGray,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(
                                                    bime
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    size: 14,
                                                    color: bime
                                                        ? Colors.green
                                                        : AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    localizations
                                                        .driver_insurance,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: bime
                                                          ? Colors.green
                                                          : AppColors
                                                                .iranianGray,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Select Load Button
                                    if (loadId != null) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              _selectLoad(loadId as int),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.lapisLazuli,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                localizations
                                                    .driver_select_load,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
                Icons.local_shipping_outlined,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: kSpacing),
            Text(
              localizations.public_loads_no_loads,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            SizedBox(height: 8),
            Text(
              localizations.public_loads_no_loads_description,
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
