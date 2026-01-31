import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/providers/settings_provider.dart';

import 'transport_new_request_screen.dart';
import 'transport_request_detail_screen.dart';

class TransportRequestsScreen extends StatefulWidget {
  const TransportRequestsScreen({super.key});

  @override
  State<TransportRequestsScreen> createState() =>
      _TransportRequestsScreenState();
}

class _TransportRequestsScreenState extends State<TransportRequestsScreen> {
  List<dynamic> requests = [];
  bool isLoading = true;
  int userLevel = 3;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 3;
    });

    // Access only for: admin (1), service provider / technician (2, 4), retailer (6)
    if (userLevel != 1 && userLevel != 2 && userLevel != 4 && userLevel != 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.trr_error_fetching_requests_status_code_403,
            ),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
      return;
    }

    fetchRequests();
  }

  Future<void> fetchRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse(
          '$baseUrl5/transport/listrequest?ts=$ts',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;

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
          requests = (data as List);
          isLoading = false;
        });
      } else if (response.statusCode == 403) {
        // Backend اجازه لیست را برای بعضی نقش‌ها نمی‌دهد (مثلاً تکنسین)،
        // اما ما صفحه را باز می‌گذاریم تا حداقل بتوانند «درخواست جدید» ثبت کنند.
        setState(() => isLoading = false);
        if (userLevel != 4) {
          // برای نقش‌های دیگر هنوز پیام عدم دسترسی را نشان می‌دهیم
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                )!.trr_error_fetching_requests_status_code_403,
              ),
            ),
          );
        }
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.trr_error_fetching_requests} (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.trr_error_connecting_server,
          ),
        ),
      );
    }
  }

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

  String _buildPiecesSummary(List<dynamic> pieces) {
    if (pieces.isEmpty) return '---';
    final safePieces = pieces.map((e) => e.toString()).toList();
    if (safePieces.length == 1) return safePieces.first;
    if (safePieces.length == 2) return '${safePieces[0]} و ${safePieces[1]}';
    return '${safePieces[0]} و ${safePieces[1]} و ...';
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

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
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
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        localizations.trr_title,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.trr_header,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.list_alt,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${requests.length} ${localizations.trr_count_label}',
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
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransportNewRequestScreen(),
                        ),
                      );
                      if (result == true) {
                        fetchRequests();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
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
                          const Icon(Icons.add, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            localizations.trr_new_request,
                            style: const TextStyle(
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
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 20,
                              bottom: 20,
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
                          const SizedBox(height: 20),
                          Text(
                            localizations.trr_loading,
                            style: const TextStyle(
                              color: AppColors.lapisLazuli,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : requests.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: fetchRequests,
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
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index] as Map;
                          final List<dynamic> pieces =
                              (request['pieces'] as List?) ?? [];
                          final createdAt = (request['created_at'] ?? '')
                              .toString();
                          final status = (request['status'] ?? 'open')
                              .toString();

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TransportRequestDetailScreen(
                                    request: Map<String, dynamic>.from(request),
                                  ),
                                ),
                              );
                            },
                            child: Container(
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
                                child: Row(
                                  textDirection: Directionality.of(context),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          status,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
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
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _buildPiecesSummary(pieces),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                textDirection:
                                                    Directionality.of(context),
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      (request['maghsad'] ??
                                                              '---')
                                                          .toString(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      textDirection:
                                                          Directionality.of(
                                                            context,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                textDirection:
                                                    Directionality.of(context),
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color:
                                                        AppColors.iranianGray,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      _formatDate(createdAt),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .iranianGray,
                                                      ),
                                                      textDirection:
                                                          Directionality.of(
                                                            context,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
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
              padding: const EdgeInsets.all(kSpacing),
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
                Icons.local_shipping_outlined,
                size: kIconSize * 2,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: kSpacing),
            Text(
              localizations.trr_no_requests,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.trr_no_requests_description,
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
