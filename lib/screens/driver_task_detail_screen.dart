import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';

class DriverTaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final bool isReport; // true if this is a report, false if it's a mission

  const DriverTaskDetailScreen({
    super.key,
    required this.task,
    this.isReport = false,
  });

  @override
  State<DriverTaskDetailScreen> createState() => _DriverTaskDetailScreenState();
}

class _DriverTaskDetailScreenState extends State<DriverTaskDetailScreen> {
  bool isLoading = false;
  late Map<String, dynamic> taskData;

  @override
  void initState() {
    super.initState();
    taskData = Map<String, dynamic>.from(widget.task);
  }

  Future<void> _refreshTaskData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return;
      }

      final taskId = taskData['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        return;
      }

      await SessionManager().onNetworkRequest();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = widget.isReport
          ? '$baseUrl5/transport/report?ts=$ts'
          : '$baseUrl5/transport/task?ts=$ts';

      final response = await http.get(
        Uri.parse(url),
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
          return;
        }

        List<dynamic> tasksList = [];
        if (data is List) {
          tasksList = data;
        } else if (data is Map && data['results'] is List) {
          tasksList = data['results'] as List<dynamic>;
        }

        final updatedTask = tasksList.firstWhere(
          (t) => t['id']?.toString() == taskId,
          orElse: () => null,
        );

        if (updatedTask != null) {
          setState(() {
            taskData = Map<String, dynamic>.from(updatedTask);
          });
        }
      }
    } catch (e) {
      print('Error refreshing task data: $e');
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

  Color _getStatusBackgroundColor(String status) {
    return _getStatusColor(status);
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

  Future<void> _completeTask() async {
    final localizations = AppLocalizations.of(context)!;
    
    // Show dialog to enter report
    final report = await showDialog<String>(
      context: context,
      builder: (context) {
        final reportController = TextEditingController();
        return AlertDialog(
          title: Text(localizations.driver_enter_report),
          content: TextField(
            controller: reportController,
            decoration: InputDecoration(
              labelText: localizations.driver_report,
              hintText: localizations.driver_report,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            maxLines: 5,
            autofocus: true,
          ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
            child: Text(localizations.home_no),
          ),
          TextButton(
              onPressed: () {
                if (reportController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.driver_report_required),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, reportController.text.trim());
              },
            child: Text(localizations.home_yes),
          ),
        ],
        );
      },
    );

    if (report == null || report.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_token_missing);
      }

      final taskId = taskData['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_task_id_missing);
      }

      await SessionManager().onNetworkRequest();

      // Confirm task with report
      final url =
          '$baseUrl5/transport/task/$taskId/confirm';
      
      final requestBody = <String, dynamic>{'report': report};

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (!mounted) return;

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(response.bodyBytes);
        final responseData = json.decode(body);
        final message =
            responseData['message']?.toString() ??
            localizations.driver_complete_task_success;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        
        // Navigate back to missions screen
        Navigator.pop(context, true);
      } else {
        final body = utf8.decode(response.bodyBytes);
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            localizations.driver_complete_task_error;
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isEmpty
                  ? AppLocalizations.of(context)!.error_unknown
                  : errorMessage,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    final String maghsad = (taskData['maghsad'] ?? '---').toString();
    final String mabda = (taskData['mabda'] ?? '---').toString();
    final String phone = (taskData['phone'] ?? '---').toString();
    final String description = (taskData['description'] ?? '---').toString();
    final String report = (taskData['report'] ?? '').toString();
    final String status = (taskData['status'] ?? 'open').toString();
    final String createdAt = (taskData['created_at'] ?? '').toString();
    final bool driverConfirm = taskData['driver_confirm'] ?? false;
    final bool customerConfirm = taskData['customer_confirm'] ?? false;
    // Handle price_transport - can be null, number, or string
    final dynamic priceTransportValue = taskData['price_transport'];
    final String priceTransport = priceTransportValue == null
        ? '---'
        : priceTransportValue.toString();

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
                        widget.isReport
                            ? localizations.driver_report_details
                            : localizations.driver_task_details,
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
            AppLocalizations.of(context)!.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _refreshTaskData,
          color: AppColors.lapisLazuli,
        child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24) +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _getStatusBackgroundColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getStatusText(status, localizations),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              _buildInfoItem(
                context,
                icon: Icons.location_city,
                title: localizations.driver_mabda,
                value: mabda,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.location_on,
                title: localizations.driver_maghsad,
                value: maghsad,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.phone,
                title: localizations.driver_phone,
                value: phone,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.attach_money,
                title: localizations.driver_price_transport,
                value: priceTransport == '---'
                    ? '---'
                    : '$priceTransport ${localizations.sls_tooman}',
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.check_circle,
                title: localizations.driver_driver_confirm,
                value: driverConfirm
                    ? localizations.driver_yes
                    : localizations.driver_no,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.verified_user,
                title: localizations.driver_customer_confirm,
                value: customerConfirm
                    ? localizations.driver_yes
                    : localizations.driver_no,
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.driver_description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : AppColors.lapisLazuli.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ),
                // Report section (only for reports)
                if (widget.isReport && report.isNotEmpty) ...[
                  SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                  Text(
                    localizations.driver_report,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : AppColors.lapisLazuli.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      report,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.black87,
                      ),
                    ),
                  ),
                ],
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              if (createdAt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.iranianGray.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: AppColors.iranianGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${localizations.driver_created_at} ${_formatDate(context, createdAt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.iranianGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Complete Task Button (only for missions when driver_confirm is false, not reports)
                if (!widget.isReport && driverConfirm == false)
                Padding(
                  padding: EdgeInsets.only(
                    top: ui.scale(base: 24, min: 20, max: 28),
                    bottom: ui.scale(base: 16, min: 12, max: 20),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _completeTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: ui.scale(base: 16, min: 14, max: 18),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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
                                const Icon(Icons.check_circle, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.driver_complete_task,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.lapisLazuli),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.iranianGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
