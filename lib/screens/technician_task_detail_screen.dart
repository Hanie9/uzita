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

class TechnicianTaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TechnicianTaskDetailScreen({super.key, required this.task});

  @override
  State<TechnicianTaskDetailScreen> createState() =>
      _TechnicianTaskDetailScreenState();
}

class _TechnicianTaskDetailScreenState
    extends State<TechnicianTaskDetailScreen> {
  bool isLoading = false;
  bool isConfirmed = false;

  // Step 1: First visit date
  DateTime? firstVisitDate;
  bool firstVisitDateSet = false;

  // Step 2: Check task fields
  final _checkTaskFormKey = GlobalKey<FormState>();
  String? selectedPiece;
  final _timeController = TextEditingController();
  final _otherCostsController = TextEditingController();
  DateTime? secondVisitDate;
  bool checkTaskSubmitted = false;

  // Step 3: Report
  final _reportFormKey = GlobalKey<FormState>();
  final _reportController = TextEditingController();

  List<String> pieceOptions = List<String>.from(kDefaultPieceOptions);

  @override
  void initState() {
    super.initState();
    isConfirmed = widget.task['technician_confirm'] == true;
    firstVisitDateSet = widget.task['first_visit_date'] != null;
    if (firstVisitDateSet) {
      try {
        firstVisitDate = DateTime.parse(widget.task['first_visit_date']);
      } catch (e) {
        firstVisitDateSet = false;
      }
    }
    // Check if check task is already submitted
    checkTaskSubmitted =
        widget.task['time'] != null &&
        widget.task['time'] != '0' &&
        widget.task['time'] != 0;
  }

  @override
  void dispose() {
    _timeController.dispose();
    _otherCostsController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  String formatDate(String? dateString, BuildContext context) {
    if (dateString == null || dateString.isEmpty) return '---';
    try {
      DateTime date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        final j = Jalali.fromDateTime(date);
        return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateString;
    }
  }

  String formatDateForAPI(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context, bool isFirstVisit) async {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';

    if (isEnglish) {
      // For English: Use Gregorian calendar
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isFirstVisit
            ? (firstVisitDate ?? DateTime.now())
            : (secondVisitDate ?? DateTime.now()),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: 365)),
        builder: (ctx, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (picked != null) {
        setState(() {
          if (isFirstVisit) {
            firstVisitDate = picked;
          } else {
            secondVisitDate = picked;
          }
        });
      }
      return;
    }

    // For Persian: Use Jalali (Shamsi) calendar
    final now = Jalali.now();
    Jalali? selectedDate = isFirstVisit
        ? (firstVisitDate != null ? Jalali.fromDateTime(firstVisitDate!) : now)
        : (secondVisitDate != null
              ? Jalali.fromDateTime(secondVisitDate!)
              : now);

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final ui = UiScale(context);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, dialogSetState) {
              return AlertDialog(
                backgroundColor: Theme.of(context).cardTheme.color,
                surfaceTintColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: ui.scale(base: 16, min: 12, max: 20),
                  vertical: ui.scale(base: 24, min: 16, max: 28),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ui.scale(base: 16, min: 12, max: 20),
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.cls_select_date_shamsi,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ui.scale(base: 18, min: 16, max: 20),
                  ),
                ),
                content: SizedBox(
                  width: ui.scale(base: screenWidth * 0.9, min: 260, max: 520),
                  height: ui.scale(
                    base: screenHeight * 0.45,
                    min: 260,
                    max: 520,
                  ),
                  child: JalaliDatePickerWidget(
                    initialDate: selectedDate!,
                    onDateSelected: (date) {
                      selectedDate = date;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLocalizations.of(context)!.cls_cancel,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedDate != null) {
                        final miladi = selectedDate!.toDateTime();
                        setState(() {
                          if (isFirstVisit) {
                            firstVisitDate = miladi;
                          } else {
                            secondVisitDate = miladi;
                          }
                        });
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lapisLazuli,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ui.scale(base: 10, min: 8, max: 12),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: ui.scale(base: 16, min: 12, max: 20),
                        vertical: ui.scale(base: 10, min: 8, max: 14),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.cls_submit,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _submitFirstVisitDate() async {
    if (firstVisitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tech_first_visit_date_error,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token is missing. Please login again.');
      }

      final taskId = widget.task['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        throw Exception('Task ID is missing');
      }

      await SessionManager().onNetworkRequest();

      final url =
          'https://device-control.liara.run/api/technician/$taskId/time-select';
      print('Sending POST request to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'first_visit_date': formatDateForAPI(firstVisitDate!),
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        setState(() {
          firstVisitDateSet = true;
          widget.task['first_visit_date'] = formatDateForAPI(firstVisitDate!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.tech_first_visit_success,
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = utf8.decode(response.bodyBytes);
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            'Error: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in _submitFirstVisitDate: $e');
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
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _submitCheckTask() async {
    if (!_checkTaskFormKey.currentState!.validate() || selectedPiece == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token is missing. Please login again.');
      }

      final taskId = widget.task['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        throw Exception('Task ID is missing');
      }

      await SessionManager().onNetworkRequest();

      final url =
          'https://device-control.liara.run/api/technician/$taskId/check-task';
      print('Sending POST request to: $url');

      final requestBody = <String, dynamic>{
        'time': int.parse(_timeController.text),
        'piece_name': selectedPiece,
        'sayer_hazine': int.parse(_otherCostsController.text),
      };

      // Include second_visit_date only if it's provided
      // If not provided, don't include it in the request
      if (secondVisitDate != null) {
        requestBody['second_visit_date'] = formatDateForAPI(secondVisitDate!);
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        setState(() {
          checkTaskSubmitted = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.tech_check_task_success,
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = utf8.decode(response.bodyBytes);
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            'Error: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in _submitCheckTask: $e');
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
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _confirmTask() async {
    if (!_reportFormKey.currentState!.validate()) {
      return;
    }

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

      final taskId = widget.task['id']?.toString() ?? '';

      if (taskId.isEmpty) {
        throw Exception('Task ID is missing');
      }

      await SessionManager().onNetworkRequest();

      final url =
          'https://device-control.liara.run/api/technician/tasks/$taskId/confirm';
      print('Sending POST request to: $url');

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
        body: json.encode({'report': _reportController.text}),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        setState(() {
          isConfirmed = true;
          widget.task['technician_confirm'] = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.tech_confirmation_success,
            ),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final body = utf8.decode(response.bodyBytes);
        print('Error response body: $body');
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            'Error: ${response.statusCode} - ${AppLocalizations.of(context)!.tech_confirmation_error}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in _confirmTask: $e');
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

  String _getUrgencyText(String? urgency, AppLocalizations localizations) {
    switch (urgency) {
      case 'normal':
        return localizations.tech_urgency_normal;
      case 'urgent':
        return localizations.tech_urgency_urgent;
      case 'very_urgent':
        return localizations.tech_urgency_very_urgent;
      default:
        return urgency ?? '---';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;

    final title = widget.task['title'] ?? '---';
    final description = widget.task['description'] ?? '---';
    final createdAt = widget.task['created_at'] ?? '';
    final status = widget.task['status']?.toString() ?? 'open';
    final address = widget.task['address'] ?? '---';
    final phone = widget.task['phone'] ?? '---';
    final urgency = widget.task['urgency']?.toString();

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
                        localizations.tech_task_details,
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
          onRefresh: () async {
            // Refresh task data if needed
          },
          color: AppColors.lapisLazuli,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: kSpacing,
              right: kSpacing,
              top: kSpacing,
              bottom: kSpacing + 40, // Extra padding at bottom for date
            ),
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

                // Task Title
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
                            Icons.assignment,
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

                // Location Information
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
                            Icons.location_on,
                            color: AppColors.lapisLazuli,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            localizations.tech_location,
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
                      // Address field - larger and more visible
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_city,
                                size: 18,
                                color: AppColors.iranianGray,
                              ),
                              SizedBox(width: 8),
                              Text(
                                localizations.tech_address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.iranianGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.lapisLazuli.withValues(
                                  alpha: 0.2,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              address,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.lapisLazuli,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildInfoRow(
                        localizations.tech_phone,
                        phone,
                        Icons.phone,
                      ),
                      if (urgency != null) ...[
                        SizedBox(height: 12),
                        _buildInfoRow(
                          localizations.tech_urgency,
                          _getUrgencyText(urgency, localizations),
                          Icons.priority_high,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Step 1: First Visit Date
                if (!firstVisitDateSet && !isConfirmed)
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.lapisLazuli,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.lapisLazuli,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              localizations.tech_first_visit_date,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.lapisLazuli.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.lapisLazuli,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    firstVisitDate != null
                                        ? formatDate(
                                            formatDateForAPI(firstVisitDate!),
                                            context,
                                          )
                                        : localizations
                                              .tech_first_visit_date_hint,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: firstVisitDate != null
                                          ? AppColors.lapisLazuli
                                          : Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.calendar_today,
                                  color: AppColors.lapisLazuli,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submitFirstVisitDate,
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
                                : Text(
                                    localizations.tech_set_first_visit,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Step 2: Check Task Form
                if (firstVisitDateSet && !checkTaskSubmitted && !isConfirmed)
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.lapisLazuli,
                        width: 2,
                      ),
                    ),
                    child: Form(
                      key: _checkTaskFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.lapisLazuli,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                localizations.tech_check_task,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lapisLazuli,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          // Piece Selection
                          Text(
                            localizations.tech_piece_name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedPiece,
                            decoration: InputDecoration(
                              hintText: localizations.tech_piece_name_hint,
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: pieceOptions.map((String part) {
                              return DropdownMenuItem<String>(
                                value: part,
                                child: Text(part),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedPiece = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return localizations.tech_piece_name_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          // Time Required
                          Text(
                            localizations.tech_time_required,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _timeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: localizations.tech_time_required_hint,
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.tech_time_required_error;
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          // Other Costs
                          Text(
                            localizations.tech_other_costs,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _otherCostsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: localizations.tech_other_costs_hint,
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.tech_other_costs_error;
                              }
                              if (int.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          // Second Visit Date (Optional)
                          Text(
                            localizations.tech_second_visit_date,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _selectDate(context, false),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.lapisLazuli.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.lapisLazuli,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      secondVisitDate != null
                                          ? formatDate(
                                              formatDateForAPI(
                                                secondVisitDate!,
                                              ),
                                              context,
                                            )
                                          : localizations
                                                .tech_second_visit_date_hint,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: secondVisitDate != null
                                            ? AppColors.lapisLazuli
                                            : Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.calendar_today,
                                    color: AppColors.lapisLazuli,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submitCheckTask,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      localizations.tech_submit_check_task,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Step 3: Report and Final Confirmation
                if (checkTaskSubmitted && !isConfirmed)
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.lapisLazuli,
                        width: 2,
                      ),
                    ),
                    child: Form(
                      key: _reportFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                                color: AppColors.lapisLazuli,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                localizations.tech_report,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lapisLazuli,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _reportController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: localizations.tech_report_hint,
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.tech_report_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _confirmTask,
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          localizations.tech_submit_report,
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

                // Date Information
                if (createdAt.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.only(top: 20),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.iranianGray),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.iranianGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
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
    );
  }
}

// Jalali Date Picker Widget for Persian calendar
class JalaliDatePickerWidget extends StatefulWidget {
  final Jalali initialDate;
  final Function(Jalali) onDateSelected;

  const JalaliDatePickerWidget({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<JalaliDatePickerWidget> createState() => _JalaliDatePickerWidgetState();
}

class _JalaliDatePickerWidgetState extends State<JalaliDatePickerWidget> {
  late Jalali currentDate;
  late Jalali selectedDate;

  final List<String> persianMonths = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  final List<String> persianWeekDays = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  @override
  void initState() {
    super.initState();
    currentDate = widget.initialDate;
    selectedDate = widget.initialDate;
  }

  void _previousMonth() {
    setState(() {
      if (currentDate.month == 1) {
        currentDate = Jalali(currentDate.year - 1, 12, 1);
      } else {
        currentDate = Jalali(currentDate.year, currentDate.month - 1, 1);
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (currentDate.month == 12) {
        currentDate = Jalali(currentDate.year + 1, 1, 1);
      } else {
        currentDate = Jalali(currentDate.year, currentDate.month + 1, 1);
      }
    });
  }

  List<Jalali?> _getDaysInMonth() {
    // Calculate days in month for Jalali calendar
    int daysInMonth;
    if (currentDate.month <= 6) {
      daysInMonth = 31;
    } else if (currentDate.month <= 11) {
      daysInMonth = 30;
    } else {
      // Esfand (12th month) - check if it's a leap year
      // Jalali leap year calculation: year % 33 == 1, 5, 9, 13, 17, 22, 26, 30
      final year = currentDate.year;
      final leapYearRemainders = [1, 5, 9, 13, 17, 22, 26, 30];
      final isLeapYear = leapYearRemainders.contains(year % 33);
      daysInMonth = isLeapYear ? 30 : 29;
    }

    final firstDayOfMonth = Jalali(currentDate.year, currentDate.month, 1);
    // Calculate weekday (0 = Saturday, 1 = Sunday, ..., 6 = Friday)
    final firstDayWeekday = (firstDayOfMonth.toDateTime().weekday + 1) % 7;

    List<Jalali?> days = [];

    // Add empty days for the beginning of the month
    for (int i = 0; i < firstDayWeekday; i++) {
      days.add(null);
    }

    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(Jalali(currentDate.year, currentDate.month, day));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();

    return Column(
      children: [
        // Header with month/year and navigation
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: Icon(Icons.chevron_left),
                iconSize: 24,
                color: AppColors.lapisLazuli,
              ),
              Text(
                '${persianMonths[currentDate.month - 1]} ${currentDate.year}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lapisLazuli,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: Icon(Icons.chevron_right),
                iconSize: 24,
                color: AppColors.lapisLazuli,
              ),
            ],
          ),
        ),

        // Week days header
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: persianWeekDays
                .map(
                  (day) => Expanded(
                    child: Container(
                      height: 36,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];

              if (day == null) {
                return Container();
              }

              final isSelected =
                  selectedDate.year == day.year &&
                  selectedDate.month == day.month &&
                  selectedDate.day == day.day;

              final isToday =
                  Jalali.now().year == day.year &&
                  Jalali.now().month == day.month &&
                  Jalali.now().day == day.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = day;
                  });
                  widget.onDateSelected(day);
                },
                child: Container(
                  margin: EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.lapisLazuli
                        : isToday
                        ? AppColors.lapisLazuli.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.lapisLazuli, width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isToday
                            ? AppColors.lapisLazuli
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
