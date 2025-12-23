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

class DriverPublicLoadsScreen extends StatefulWidget {
  const DriverPublicLoadsScreen({super.key});

  @override
  State<DriverPublicLoadsScreen> createState() =>
      _DriverPublicLoadsScreenState();
}

class _DriverPublicLoadsScreenState extends State<DriverPublicLoadsScreen> {
  List<dynamic> loads = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLoads();
  }

  Future<void> _fetchLoads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse(
          'https://device-control.liara.run/api/transport/listrequest?ts=$ts',
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

        List<dynamic> all = [];
        if (data is List) {
          all = data;
        } else if (data is Map && data['results'] is List) {
          all = data['results'] as List<dynamic>;
        }

        // Public loads: status = open and driver == null
        final filtered = all.where((item) {
          if (item is! Map) return false;
          final status = (item['status'] ?? '').toString();
          final driver = item['driver'];
          return status == 'open' && driver == null;
        }).toList();

        setState(() {
          loads = filtered;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  String _formatDate(BuildContext context, String dateString) {
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
                        localizations.nav_public_loads,
                        style:
                            Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
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
            Provider.of<SettingsProvider>(context, listen: false)
                        .selectedLanguage ==
                    'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
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
                ? Center(
                    child: Text(
                      localizations.trr_no_requests,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchLoads,
                    color: AppColors.lapisLazuli,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: kSpacing,
                        right: kSpacing,
                        top: kSpacing,
                        bottom: kSpacing +
                            MediaQuery.of(context).padding.bottom +
                            20,
                      ),
                      itemCount: loads.length,
                      itemBuilder: (context, index) {
                        final load = loads[index] as Map;
                        final List<dynamic> pieces =
                            (load['pieces'] as List?) ?? [];
                        final createdAt =
                            (load['created_at'] ?? '').toString();

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
                              color: Theme.of(context).brightness ==
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
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.lapisLazuli,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _buildPiecesSummary(pieces),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: AppColors.iranianGray,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              createdAt.isNotEmpty
                                                  ? _formatDate(
                                                      context,
                                                      createdAt,
                                                    )
                                                  : '---',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.iranianGray,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}



