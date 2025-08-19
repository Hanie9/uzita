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

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  List services = [];
  bool isLoading = true;

  Future<void> fetchServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl5/listservice/?ts=$ts'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['error'].toString())));
          setState(() => isLoading = false);
          return;
        }
        setState(() {
          services = (data as List);
          isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.sls_error_fetching_services_status_code_403,
            ),
          ),
        );
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.sls_error_fetching_services} (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sls_error_connecting),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchServices();
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Back arrow
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.sls_request_service,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  // Right - Logo
                  Row(
                    children: [
                      Image.asset(
                        'assets/logouzita.png',
                        height: screenHeight * 0.08,
                        width: screenHeight * 0.08,
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
            // Enhanced Header
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  // Service Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.build_circle_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  // Service Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.sls_request_service,
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
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${services.length} ${AppLocalizations.of(context)!.sls_request}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
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
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SendServiceScreen()),
                      );
                      if (result == true) fetchServices();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.sls_new,
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
            // Enhanced Service List
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
                            AppLocalizations.of(context)!.sls_loading,
                            style: TextStyle(
                              color: AppColors.lapisLazuli,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : services.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: fetchServices,
                      color: AppColors.lapisLazuli,
                      child: ListView.builder(
                        padding: EdgeInsets.all(kSpacing),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final title = service['title'] ?? '---';
                          final description = service['description'] ?? '---';
                          final pieceName = service['piece']?['name'] ?? '---';
                          final hazine = service['hazine']?.toString() ?? '0';
                          final createdAt = service['created_at'] ?? '';
                          return Container(
                            margin: EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : AppColors.lapisLazuli.withValues(
                                          alpha: 0.08,
                                        ),
                                  blurRadius: 15,
                                  offset: Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[600]!
                                    : AppColors.lapisLazuli.withValues(
                                        alpha: 0.1,
                                      ),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    textDirection: Directionality.of(context),
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.lapisLazuli.withValues(
                                                alpha: 0.15,
                                              ),
                                              AppColors.lapisLazuli.withValues(
                                                alpha: 0.08,
                                              ),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.lapisLazuli
                                                .withValues(alpha: 0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.build_circle,
                                          color: AppColors.lapisLazuli,
                                          size: 32,
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                          textAlign:
                                              Directionality.of(context) ==
                                                  TextDirection.rtl
                                              ? TextAlign.right
                                              : TextAlign.left,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 18),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.lapisLazuli.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.lapisLazuli.withValues(
                                          alpha: 0.1,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.sls_description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.lapisLazuli,
                                          ),
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          description,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color
                                                ?.withValues(alpha: 0.8),
                                            height: 1.4,
                                          ),
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                          textAlign:
                                              Directionality.of(context) ==
                                                  TextDirection.rtl
                                              ? TextAlign.right
                                              : TextAlign.left,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  Row(
                                    textDirection: Directionality.of(context),
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.lapisLazuli
                                                .withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: AppColors.lapisLazuli
                                                  .withValues(alpha: 0.1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.sls_need_piece,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.iranianGray,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textDirection:
                                                    Directionality.of(context),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                pieceName,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.lapisLazuli,
                                                ),
                                                textDirection:
                                                    Directionality.of(context),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.bronzeGold.withValues(
                                                alpha: 0.15,
                                              ),
                                              AppColors.bronzeGold.withValues(
                                                alpha: 0.08,
                                              ),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.bronzeGold
                                                .withValues(alpha: 0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.sls_all_cost,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.iranianGray,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textDirection: Directionality.of(
                                                context,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '$hazine ${AppLocalizations.of(context)!.sls_tooman}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.maroon,
                                              ),
                                              textDirection: Directionality.of(
                                                context,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (createdAt.isNotEmpty) ...[
                                    SizedBox(height: 16),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.iranianGray.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: AppColors.iranianGray,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '${AppLocalizations.of(context)!.sls_date_register} ${formatDate(createdAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.iranianGray,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                          ),
                                        ],
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.build_circle_outlined,
              size: kIconSize * 2,
              color: AppColors.lapisLazuli,
            ),
          ),
          SizedBox(height: kSpacing),
          Text(
            AppLocalizations.of(context)!.sls_no_request,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.lapisLazuli,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.sls_no_request_description,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
