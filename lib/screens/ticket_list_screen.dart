import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/screens/create_ticket_screen.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/ticket_detail_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/ticket_card.dart';
import 'package:uzita/utils/ticket_class.dart';
import 'package:uzita/utils/shared_loading.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ui_scale.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  List<Ticket> tickets = [];
  bool loading = true;
  String error = '';
  bool userActive = false;
  String username = '';
  int userLevel = 3;
  String userRoleTitle = '';

  @override
  void initState() {
    super.initState();
    loadUserData().then((_) {
      // Only fetch tickets if user is active
      if (userActive) {
        fetchTickets();
      }
    });
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username =
          prefs.getString('username') ?? AppLocalizations.of(context)!.tls_user;
      userLevel = prefs.getInt('level') ?? 3;
      userActive = prefs.getBool('active') ?? false;

      // Set user role title
      if (prefs.getBool('modir') ?? false) {
        userRoleTitle = AppLocalizations.of(
          context,
        )!.tls_company_representative;
      } else if (userLevel == 2) {
        userRoleTitle = AppLocalizations.of(context)!.tls_installer;
      } else if (userLevel == 3) {
        userRoleTitle = AppLocalizations.of(context)!.tls_user;
      } else if (userLevel == 1) {
        userRoleTitle = AppLocalizations.of(context)!.tls_admin;
      }

      // If user is not active, stop loading immediately
      if (!userActive) {
        loading = false;
      }
    });
  }

  Future<void> fetchTickets() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          error = AppLocalizations.of(context)!.tls_login_again;
          loading = false;
        });
        return;
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$baseUrl/listticket/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      print('Response status: ${response.statusCode}');
      final respBody = utf8.decode(response.bodyBytes);
      print(
        'Response body (prefix): ${respBody.length > 300 ? respBody.substring(0, 300) : respBody}',
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(respBody);

        if (data is Map && data['error'] != null) {
          setState(() {
            error = data['error'].toString();
            loading = false;
          });
          return;
        }

        List<dynamic> list;
        if (data is List) {
          list = data;
        } else if (data is Map && data['results'] is List) {
          list = List.from(data['results']);
        } else if (data is Map && data['data'] is List) {
          list = List.from(data['data']);
        } else {
          setState(() {
            error = AppLocalizations.of(context)!.tls_unexpected_error;
            loading = false;
          });
          return;
        }

        setState(() {
          tickets = list.map((json) => Ticket.fromJson(json)).toList();
          loading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          error = AppLocalizations.of(context)!.tls_no_access;
          loading = false;
        });
      } else {
        setState(() {
          error =
              '${AppLocalizations.of(context)!.tls_error_fetching_tickets} ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context)!.tls_error_connecting;
        loading = false;
      });
    }
  }

  String convertToShamsi(String dateTime) {
    try {
      DateTime dt = DateTime.parse(dateTime);
      if (Localizations.localeOf(context).languageCode == 'en') {
        // Miladi
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      } else {
        // Shamsi
        Jalali shamsiDate = Jalali.fromDateTime(dt);
        return '${shamsiDate.year}/${shamsiDate.month.toString().padLeft(2, '0')}/${shamsiDate.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return AppLocalizations.of(context)!.tls_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);
    final theme = Theme.of(context);
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
                children: [
                  // Left side - Back button and title
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
                        AppLocalizations.of(context)!.tls_title,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                    ],
                  ),

                  // Right side - Logo
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: userActive
          ? SafeArea(
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
                    // Enhanced Header Box (Blue Box)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
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
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Ticket Icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.support_agent,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          // Ticket Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.tls_title,
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
                                    Text(
                                      '${tickets.length} ${AppLocalizations.of(context)!.tls_ticket_count}',
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
                          ),
                          // Add Button
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateTicketScreen(),
                                ),
                              ).then((_) => fetchTickets());
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.tls_new_ticket,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // List Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          ui.scale(base: 12, min: 10, max: 16),
                          ui.scale(base: 8, min: 6, max: 12),
                          ui.scale(base: 12, min: 10, max: 16),
                          ui.scale(base: 8, min: 6, max: 12) +
                              MediaQuery.of(context).padding.bottom,
                        ),
                        child: loading
                            ? Center(
                                child: SharedLoading(
                                  title: AppLocalizations.of(
                                    context,
                                  )!.tls_loading,
                                ),
                              )
                            : error.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    ui.scale(base: 20, min: 14, max: 24),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      ui.scale(base: 24, min: 16, max: 28),
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardTheme.color,
                                      borderRadius: BorderRadius.circular(
                                        ui.scale(base: 16, min: 12, max: 20),
                                      ),
                                      border: Border.all(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.red[800]!.withValues(
                                                alpha: 0.3,
                                              )
                                            : Colors.red[100]!,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.black.withValues(
                                                  alpha: 0.3,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            ui.scale(
                                              base: 16,
                                              min: 12,
                                              max: 20,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.red[900]!.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : Colors.red[50],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.error_outline,
                                            size: ui.scale(
                                              base: 48,
                                              min: 36,
                                              max: 56,
                                            ),
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.red[300]
                                                : Colors.red[400],
                                          ),
                                        ),
                                        SizedBox(
                                          height: ui.scale(
                                            base: 20,
                                            min: 14,
                                            max: 26,
                                          ),
                                        ),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.tls_error_loading,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.titleMedium?.color,
                                            fontSize: ui.scale(
                                              base: 18,
                                              min: 15,
                                              max: 20,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Vazir',
                                          ),
                                        ),
                                        SizedBox(
                                          height: ui.scale(
                                            base: 8,
                                            min: 6,
                                            max: 12,
                                          ),
                                        ),
                                        Text(
                                          error,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            fontSize: ui.scale(
                                              base: 14,
                                              min: 12,
                                              max: 16,
                                            ),
                                            fontFamily: 'Vazir',
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(
                                          height: ui.scale(
                                            base: 20,
                                            min: 14,
                                            max: 26,
                                          ),
                                        ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: fetchTickets,
                                            icon: Icon(
                                              Icons.refresh,
                                              size: ui.scale(
                                                base: 20,
                                                min: 18,
                                                max: 24,
                                              ),
                                            ),
                                            label: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.tls_try_again,
                                              style: TextStyle(
                                                fontFamily: 'Vazir',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.lapisLazuli,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical: ui.scale(
                                                  base: 14,
                                                  min: 12,
                                                  max: 16,
                                                ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      ui.scale(
                                                        base: 12,
                                                        min: 10,
                                                        max: 14,
                                                      ),
                                                    ),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : tickets.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    ui.scale(base: 20, min: 14, max: 24),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(
                                          ui.scale(base: 24, min: 16, max: 28),
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.lapisLazuli.withValues(
                                                alpha: 0.1,
                                              ),
                                              AppColors.lapisLazuli.withValues(
                                                alpha: 0.05,
                                              ),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.lapisLazuli
                                                .withValues(alpha: 0.2),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.support_agent,
                                          size: ui.scale(
                                            base: 64,
                                            min: 48,
                                            max: 72,
                                          ),
                                          color: AppColors.lapisLazuli,
                                        ),
                                      ),
                                      SizedBox(
                                        height: ui.scale(
                                          base: 24,
                                          min: 16,
                                          max: 28,
                                        ),
                                      ),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.tls_no_tickets,
                                        style: TextStyle(
                                          fontSize: ui.scale(
                                            base: 22,
                                            min: 18,
                                            max: 24,
                                          ),
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.color,
                                          fontFamily: 'Vazir',
                                        ),
                                      ),
                                      SizedBox(
                                        height: ui.scale(
                                          base: 12,
                                          min: 8,
                                          max: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: ui.scale(
                                            base: 16,
                                            min: 12,
                                            max: 20,
                                          ),
                                          vertical: ui.scale(
                                            base: 12,
                                            min: 8,
                                            max: 14,
                                          ),
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.blue[900]!.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            ui.scale(
                                              base: 12,
                                              min: 10,
                                              max: 14,
                                            ),
                                          ),
                                          border: Border.all(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.blue[700]!.withValues(
                                                    alpha: 0.3,
                                                  )
                                                : Colors.blue[100]!,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: ui.scale(
                                                base: 18,
                                                min: 14,
                                                max: 20,
                                              ),
                                              color: AppColors.lapisLazuli,
                                            ),
                                            SizedBox(
                                              width: ui.scale(
                                                base: 8,
                                                min: 6,
                                                max: 12,
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.tls_send_new_hint,
                                                style: TextStyle(
                                                  fontSize: ui.scale(
                                                    base: 14,
                                                    min: 12,
                                                    max: 16,
                                                  ),
                                                  color: AppColors.lapisLazuli,
                                                  fontFamily: 'Vazir',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: fetchTickets,
                                color: AppColors.lapisLazuli,
                                child: ListView.builder(
                                  padding: EdgeInsets.only(top: 8, bottom: 8),
                                  itemCount: tickets.length,
                                  itemBuilder: (context, index) {
                                    final ticket = tickets[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: TicketCard(
                                        ticket: ticket,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  TicketDetailScreen(
                                                    ticketId: ticket.id,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _buildInactiveState(),
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
                Icons.support_agent_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),

            SizedBox(height: 24),

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

            SizedBox(height: 12),

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

            SizedBox(height: 32),

            // Contact Admin Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.tls_contact_admin,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.tls_contact_admin_button,
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
