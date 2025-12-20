import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/services/session_manager.dart';
import 'dart:convert';

class ServiceProviderServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const ServiceProviderServiceDetailScreen({super.key, required this.service});

  @override
  State<ServiceProviderServiceDetailScreen> createState() =>
      _ServiceProviderServiceDetailScreenState();
}

class _ServiceProviderServiceDetailScreenState
    extends State<ServiceProviderServiceDetailScreen> {
  bool isLoading = false;
  String? currentStatus;
  int userLevel = 2; // Default to level 2 (service provider)

  @override
  void initState() {
    super.initState();
    currentStatus = widget.service['status']?.toString();
    print('Initial status from widget.service: $currentStatus');
    _loadUserLevel();
    // Fetch latest service data from API to ensure status is up to date
    _fetchServiceDetails();
  }

  Future<void> _loadUserLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 2;
    });
  }

  Future<void> _fetchServiceDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final serviceId = widget.service['id']?.toString() ?? '';

      if (serviceId.isEmpty) {
        return;
      }

      await SessionManager().onNetworkRequest();

      // Try to fetch from both pending and completed lists to get latest status
      final ts = DateTime.now().millisecondsSinceEpoch;

      http.Response? pendingResponse;
      http.Response? completedResponse;

      // For level 1, use /listservice/ endpoint
      // For level 2, use /serviceprovider/pending/ and /serviceprovider/completed/
      if (userLevel == 1) {
        // Level 1 uses /listservice/ endpoint
        final allServicesResponse = await http.get(
          Uri.parse('$baseUrl5/listservice/?ts=$ts'),
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Connection': 'close',
          },
        );

        if (allServicesResponse.statusCode == 200) {
          final body = utf8.decode(allServicesResponse.bodyBytes);
          final dynamic data = json.decode(body);
          if (data is List) {
            // Search for the service in the list
            for (var service in data) {
              if (service is Map) {
                final id = service['id'];
                if (id != null && id.toString() == serviceId) {
                  // Found the service, update it
                  if (mounted) {
                    setState(() {
                      final updatedStatus = service['status']?.toString();
                      if (updatedStatus != null) {
                        currentStatus = updatedStatus;
                        widget.service['status'] = updatedStatus;
                      }
                      // Update all service fields from API response
                      widget.service.addAll(Map<String, dynamic>.from(service));
                      print(
                        'Updated service for level 1: customer_confirm=${service['customer_confirm']}, technician_confirm=${service['technician_confirm']}, status=$updatedStatus',
                      );
                    });
                  }
                  return; // Found and updated, exit
                }
              }
            }
          }
        }
        return; // For level 1, we're done
      }

      // Level 2 uses serviceprovider endpoints
      // Check pending services
      pendingResponse = await http.get(
        Uri.parse('$baseUrl5/serviceprovider/pending/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      // Check completed services
      completedResponse = await http.get(
        Uri.parse('$baseUrl5/serviceprovider/completed/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      // Search for this service in both lists (only for level 2)
      Map<String, dynamic>? updatedService;

      if (pendingResponse.statusCode == 200) {
        final body = utf8.decode(pendingResponse.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is List) {
          for (var service in data) {
            if (service is Map) {
              final id = service['id'];
              if (id != null && id.toString() == serviceId) {
                updatedService = Map<String, dynamic>.from(service);
                print(
                  'Found service in pending list with status: ${updatedService['status']}, customer_confirm: ${updatedService['customer_confirm']}, technician_confirm: ${updatedService['technician_confirm']}',
                );
                // Don't break, check completed list too for more up-to-date status
              }
            }
          }
        }
      }

      if (completedResponse.statusCode == 200) {
        final body = utf8.decode(completedResponse.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is List) {
          for (var service in data) {
            if (service is Map) {
              final id = service['id'];
              if (id != null && id.toString() == serviceId) {
                // If found in completed, use it (it's more up-to-date)
                updatedService = Map<String, dynamic>.from(service);
                print(
                  'Found service in completed list with status: ${updatedService['status']}',
                );
                break;
              }
            }
          }
        }
      }

      // Update service data with latest from server
      if (updatedService != null) {
        final updatedStatus = updatedService['status']?.toString();
        if (updatedStatus != null) {
          print(
            'Found service in API, updating status from $currentStatus to $updatedStatus',
          );
          if (mounted) {
            setState(() {
              currentStatus = updatedStatus;
              widget.service['status'] = updatedStatus;
              // Update all service fields from API response
              if (updatedService != null) {
                widget.service.addAll(updatedService);
                // Update other fields if needed
                final technician = updatedService['technician'];
                if (technician != null) {
                  widget.service['technician'] = technician;
                }
              }
            });
          }
        } else {
          print('Service found in API but status is null');
        }
      } else {
        print('Service not found in pending or completed lists');
        print(
          'Current status from widget.service: ${widget.service['status']}',
        );
        print('Current status from state: $currentStatus');
        // Keep current status from widget.service if service not found in API
        // This is a fallback for when API doesn't return the service yet
      }
    } catch (e) {
      // Log error but continue with existing data
      print('Error fetching service details: $e');
    }
  }

  String formatDate(String dateString, BuildContext context) {
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

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildStarRating(double grade, BuildContext context) {
    if (grade == 0) {
      return Text(
        AppLocalizations.of(context)!.sps_no_rating,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.iranianGray,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Round to nearest integer (only whole numbers 1-5)
    final int roundedGrade = grade.round().clamp(1, 5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starNumber = index + 1;
        if (roundedGrade >= starNumber) {
          // Full star
          return Icon(Icons.star, color: Colors.amber, size: 20);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.grey[400], size: 20);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;

    final title = widget.service['title'] ?? '---';
    final description = widget.service['description'] ?? '---';
    final piece = widget.service['piece'];
    final pieceName = piece?['name'] ?? '---';
    final pieceCode = piece?['code'] ?? '---';
    final piecePrice = piece?['price']?.toString() ?? '0';
    final hazine = widget.service['hazine']?.toString() ?? '0';
    final sayerHazine = widget.service['sayer_hazine']?.toString() ?? '0';
    final time = widget.service['time']?.toString() ?? '0';
    final createdAt = widget.service['created_at'] ?? '';
    final status = currentStatus ?? widget.service['status'] ?? 'open';
    final technician = widget.service['technician'];
    final technicianGrade = technician != null
        ? ((technician['grade'] ?? 0) as num).toDouble()
        : 0.0;
    final serviceGrade = ((widget.service['grade'] ?? 0) as num).toDouble();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
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
                        localizations.sps_service_details,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
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
      body: Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _fetchServiceDetails,
          color: AppColors.lapisLazuli,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(kSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Banner
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: _getStatusBackgroundColor(status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        _getStatusText(status, localizations),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Service Title
                Container(
                  padding: EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build_circle,
                            color: AppColors.lapisLazuli,
                            size: 24,
                          ),
                          SizedBox(width: 12),
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
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lapisLazuli.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.sls_description,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.lapisLazuli,
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Piece Information
                Container(
                  padding: EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings,
                            color: AppColors.lapisLazuli,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            localizations.sls_need_piece,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${localizations.sls_need_piece}:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.iranianGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  pieceName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lapisLazuli,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${localizations.sps_piece_code}:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                pieceCode,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.lapisLazuli,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${localizations.sps_piece_price}:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$piecePrice ${localizations.sls_tooman}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.maroon,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Cost and Time Information
                Container(
                  padding: EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            color: AppColors.bronzeGold,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            localizations.sps_cost_info,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${localizations.sps_piece_cost}:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.iranianGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$piecePrice ${localizations.sls_tooman}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lapisLazuli,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${localizations.sps_other_costs}:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.iranianGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$sayerHazine ${localizations.sls_tooman}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lapisLazuli,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.bronzeGold.withValues(alpha: 0.15),
                              AppColors.bronzeGold.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.bronzeGold.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations.sls_all_cost,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.iranianGray,
                              ),
                            ),
                            Text(
                              '$hazine ${localizations.sls_tooman}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.maroon,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: AppColors.iranianGray,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${localizations.sps_time_required}:',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.iranianGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '$time ${localizations.sps_minutes}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Technician Information (if exists)
                if (technician != null) ...[
                  Container(
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: AppColors.lapisLazuli,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              localizations.sps_technician,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.sps_technician_name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.iranianGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '${technician['first_name'] ?? ''} ${technician['last_name'] ?? ''}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lapisLazuli,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.sps_technician_phone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.iranianGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    technician['phone'] ?? '---',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.lapisLazuli,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Ratings Section (only shown if at least one rating exists)
                if (technician != null || serviceGrade > 0) ...[
                  Container(
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star_outline,
                              color: AppColors.lapisLazuli,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              localizations.sps_ratings,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Technician Average Grade (only if technician exists)
                        if (technician != null) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.sps_technician_grade,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildStarRating(technicianGrade, context),
                            ],
                          ),
                          SizedBox(height: 16),
                        ],
                        // Service Grade (Admin's rating for this service) - only if admin has rated
                        if (serviceGrade > 0) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.sps_service_grade,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildStarRating(serviceGrade, context),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],

                // Date Information
                if (createdAt.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.iranianGray.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.iranianGray,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${localizations.sls_date_register} ${formatDate(createdAt, context)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.iranianGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 20),

                // Confirm Completion Button
                // For level 1 (admin): Show if status is 'assigned'
                // For level 2 (service provider): Show if status is 'assigned'
                if ((userLevel == 1 && status == 'assigned') ||
                    (userLevel == 2 && status == 'assigned'))
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 20),
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () => _showRatingDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  localizations.sps_confirm_completion,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(localizations.sps_rating_dialog_title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.sps_select_rating,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final rating = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedRating = rating;
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              selectedRating >= rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: selectedRating >= rating
                                  ? Colors.amber
                                  : Colors.grey,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 24),
                    Text(
                      localizations.sps_comment,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: localizations.sps_comment_hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(AppLocalizations.of(context)!.shareddrawer_no),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.sps_rating_required),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await _confirmService(
                      selectedRating,
                      commentController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lapisLazuli,
                  ),
                  child: Text(
                    localizations.sps_confirm_button,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmService(int grade, String comment) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token is missing. Please login again.');
      }

      final serviceId = widget.service['id']?.toString() ?? '';

      if (serviceId.isEmpty) {
        throw Exception('Service ID is missing');
      }

      await SessionManager().onNetworkRequest();

      final Map<String, dynamic> requestBody = {};
      if (grade > 0) {
        requestBody['grade'] = grade;
      }
      if (comment.isNotEmpty && comment.trim().isNotEmpty) {
        requestBody['comment'] = comment.trim();
      }

      final url =
          'https://device-control.liara.run/api/service-confirm/$serviceId';
      print('Sending POST request to: $url');
      print('Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(response.bodyBytes);
        final responseData = json.decode(body);

        // Get updated status from response (could be 'confirm' or 'done')
        // If technician also confirmed, status will be 'done', otherwise 'confirm'
        // If status is not in response, default to 'confirm'
        final updatedStatus = responseData['status']?.toString() ?? 'confirm';

        // Update customer_confirm if present in response
        // Handle both boolean and string values from API
        final customerConfirmValue =
            responseData['customer_confirm'] ??
            widget.service['customer_confirm'] ??
            false;
        final updatedCustomerConfirm =
            customerConfirmValue == true ||
            customerConfirmValue == 'true' ||
            customerConfirmValue == 1;

        print('Updated status from API response: $updatedStatus');
        print(
          'Updated customer_confirm from API response: $updatedCustomerConfirm',
        );

        if (!mounted) return;

        // Update service status locally immediately
        setState(() {
          currentStatus = updatedStatus;
          widget.service['status'] = updatedStatus;
          widget.service['customer_confirm'] = updatedCustomerConfirm;
          print('Status updated to: $updatedStatus (stored in widget.service)');
          print('Customer confirm updated to: $updatedCustomerConfirm');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.sps_confirmation_success,
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Wait a bit for API to update, then fetch latest service data
        // API might need time to move service from pending to completed
        await Future.delayed(Duration(milliseconds: 1500));

        // Fetch latest service data from API to get accurate status
        print('Fetching latest service data after confirmation...');
        await _fetchServiceDetails();
        print('Current status after fetch: $currentStatus');

        // Wait a bit for the snackbar to show, then pop
        await Future.delayed(Duration(milliseconds: 500));

        if (mounted) {
          // Update UI and pop back to refresh the list
          Navigator.pop(context, true);
        }
      } else {
        final body = utf8.decode(response.bodyBytes);
        print('Error response body: $body');
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            'Error: ${response.statusCode} - ${AppLocalizations.of(context)!.sps_confirmation_error}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in _confirmService: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
