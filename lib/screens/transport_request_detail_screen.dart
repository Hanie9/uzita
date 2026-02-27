import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';

class TransportRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const TransportRequestDetailScreen({super.key, required this.request});

  @override
  State<TransportRequestDetailScreen> createState() =>
      _TransportRequestDetailScreenState();
}

class _TransportRequestDetailScreenState
    extends State<TransportRequestDetailScreen> {
  bool isLoading = false;
  bool isSubmittingRating = false;
  int? selectedGrade;
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? driverInfo;
  int userLevel = 3;
  late Map<String, dynamic> requestData;

  @override
  void initState() {
    super.initState();
    requestData = Map<String, dynamic>.from(widget.request);
    _loadUserData();
    _extractDriverInfo();
    _loadExistingRating();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 3;
    });
  }

  void _extractDriverInfo() {
    final driver = requestData['driver'];
    if (driver != null) {
      if (driver is Map) {
        setState(() {
          driverInfo = Map<String, dynamic>.from(driver);
        });
      } else if (driver is String) {
        // If driver is just a string (username), create a simple map
        setState(() {
          driverInfo = {'username': driver};
        });
      }
    }
  }

  Future<void> _refreshRequestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return;
      }

      final requestId = requestData['id']?.toString() ?? '';
      if (requestId.isEmpty) {
        return;
      }

      await SessionManager().onNetworkRequest();

      final ts = DateTime.now().millisecondsSinceEpoch;
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
          return;
        }

        if (data is List) {
          final updatedRequest = data.firstWhere(
            (r) => r['id']?.toString() == requestId,
            orElse: () => null,
          );

          if (updatedRequest != null) {
            // Update requestData, driver info, and rating in one setState
            setState(() {
              requestData = Map<String, dynamic>.from(updatedRequest);

              // Update driver info
              final driver = requestData['driver'];
              if (driver != null) {
                if (driver is Map) {
                  driverInfo = Map<String, dynamic>.from(driver);
                } else if (driver is String) {
                  driverInfo = {'username': driver};
                }
              }

              // Update existing rating
              final comment = requestData['comment'];
              final grade = requestData['grade'];

              if (comment != null &&
                  comment.toString().isNotEmpty &&
                  comment.toString() != '---') {
                _commentController.text = comment.toString();
              }

              if (grade != null &&
                  grade.toString().isNotEmpty &&
                  grade.toString() != '---') {
                final gradeInt = int.tryParse(grade.toString());
                if (gradeInt != null && gradeInt >= 1 && gradeInt <= 5) {
                  selectedGrade = gradeInt;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error refreshing request data: $e');
    }
  }

  void _loadExistingRating() {
    final comment = requestData['comment'];
    final grade = requestData['grade'];

    if (comment != null &&
        comment.toString().isNotEmpty &&
        comment.toString() != '---') {
      _commentController.text = comment.toString();
    }

    if (grade != null &&
        grade.toString().isNotEmpty &&
        grade.toString() != '---') {
      final gradeInt = int.tryParse(grade.toString());
      if (gradeInt != null && gradeInt >= 1 && gradeInt <= 5) {
        setState(() {
          selectedGrade = gradeInt;
        });
      }
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

  String _getDriverDisplayName() {
    if (driverInfo == null) {
      return AppLocalizations.of(context)!.trd_unknown;
    }

    // Try to get username first, then first_name + last_name, then just username
    final username = driverInfo!['username']?.toString() ?? '';
    final firstName = driverInfo!['first_name']?.toString() ?? '';
    final lastName = driverInfo!['last_name']?.toString() ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (username.isNotEmpty) {
      return username;
    }

    return AppLocalizations.of(context)!.trd_unknown;
  }

  String _getDriverPhone() {
    if (driverInfo == null) return '---';
    return driverInfo!['phone']?.toString() ?? '---';
  }

  String _getDriverCode() {
    if (driverInfo == null) return '---';
    return driverInfo!['code']?.toString() ?? '---';
  }

  String _getDriverAddress() {
    if (driverInfo == null) return '---';
    return driverInfo!['address']?.toString() ?? '---';
  }

  String _getDriverCity() {
    if (driverInfo == null) return '---';
    return driverInfo!['city']?.toString() ?? '---';
  }

  double? _getDriverAverageRating() {
    if (driverInfo == null) return null;
    final avgRating = driverInfo!['grade'] ?? driverInfo!['grade'];
    if (avgRating == null) return null;
    if (avgRating is num) {
      return avgRating.toDouble();
    }
    final avgRatingStr = avgRating.toString();
    return double.tryParse(avgRatingStr);
  }

  Future<void> _submitRating() async {
    final localizations = AppLocalizations.of(context)!;

    // Check if grade is selected
    if (selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.trd_grade_required),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if comment is provided
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.trd_comment_required),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSubmittingRating = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_token_missing);
      }

      final requestId = requestData['id']?.toString() ?? '';
      if (requestId.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_request_id_missing);
      }

      await SessionManager().onNetworkRequest();

      final Map<String, dynamic> requestBody = {'grade': selectedGrade!};

      if (_commentController.text.trim().isNotEmpty) {
        requestBody['comment'] = _commentController.text.trim();
      }

      // Try /rate endpoint first for status 'done' (rating after completion)
      // If it fails, try /confirm endpoint
      final status = requestData['status']?.toString() ?? 'open';
      String url =
          '$baseUrl5/transport/request/$requestId/confirm';

      print('Sending POST request to: $url');
      print('Request body: ${json.encode(requestBody)}');
      print('Status: $status');

      http.Response response = await http.post(
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

      // If 403 or other error, try alternative endpoint
      if (response.statusCode == 403 ||
          (response.statusCode != 200 && response.statusCode != 201)) {
        final altUrl = status == 'done'
            ? '$baseUrl5/transport/request/$requestId/confirm'
            : '$baseUrl5/transport/request/$requestId/rate';
        print('Trying alternative endpoint: $altUrl');

        response = await http.post(
          Uri.parse(altUrl),
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

        print('Alternative response status code: ${response.statusCode}');
        print('Alternative response body: ${response.body}');
      }

      if (!mounted) return;

      setState(() {
        isSubmittingRating = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh request data from API to get updated driver average rating and grade
        await _refreshRequestData();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.trd_rating_submitted_success,
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
            AppLocalizations.of(context)!.trd_rating_submit_error;
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSubmittingRating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _completeTask() async {
    final localizations = AppLocalizations.of(context)!;
    int? taskGrade;
    final TextEditingController commentController = TextEditingController();

    // Show dialog to enter grade and comment
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Directionality(
        textDirection: localizations.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(localizations.trd_complete_task),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.trd_select_grade,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final grade = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            taskGrade = grade;
                          });
                        },
                        child: Icon(
                          taskGrade != null && grade <= taskGrade!
                              ? Icons.star
                              : Icons.star_border,
                          color: taskGrade != null && grade <= taskGrade!
                              ? Colors.amber
                              : Colors.grey,
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localizations.trd_comment,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: localizations.trd_comment_hint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(localizations.trd_cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'grade': taskGrade,
                    'comment': commentController.text.trim(),
                  });
                },
                child: Text(localizations.trd_submit),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_token_missing);
      }

      final requestId = requestData['id']?.toString() ?? '';
      if (requestId.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.error_request_id_missing);
      }

      await SessionManager().onNetworkRequest();

      final url =
          '$baseUrl5/transport/request/$requestId/confirm';

      final requestBody = <String, dynamic>{};
      if (result['grade'] != null) {
        requestBody['grade'] = result['grade'];
      }
      if (result['comment'] != null &&
          result['comment'].toString().trim().isNotEmpty) {
        requestBody['comment'] = result['comment'];
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

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(response.bodyBytes);
        final responseData = json.decode(body);
        final message =
            responseData['message']?.toString() ??
            localizations.trd_complete_task_success;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        // Navigate back with success
        Navigator.pop(context, true);
      } else {
        final body = utf8.decode(response.bodyBytes);
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            localizations.trd_complete_task_error;
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', '').isEmpty
                  ? AppLocalizations.of(context)!.error_unknown
                  : e.toString().replaceAll('Exception: ', ''),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showRatingDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: localizations.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: AlertDialog(
          title: Text(localizations.trd_rate_driver),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.trd_select_grade,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final grade = index + 1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedGrade = grade;
                        });
                        Navigator.pop(context);
                        _showRatingDialog();
                      },
                      child: Icon(
                        selectedGrade != null && grade <= selectedGrade!
                            ? Icons.star
                            : Icons.star_border,
                        color: selectedGrade != null && grade <= selectedGrade!
                            ? Colors.amber
                            : Colors.grey,
                        size: 40,
                      ),
                    );
                  }),
                ),
                if (selectedGrade != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${localizations.trd_selected_grade}: $selectedGrade',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.iranianGray,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  localizations.trd_comment_label,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: localizations.trd_comment_hint,
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
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.trd_cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitRating();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapisLazuli,
                foregroundColor: Colors.white,
              ),
              child: Text(localizations.trd_submit),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    final List<dynamic> pieces = (requestData['pieces'] as List?) ?? [];
    final String maghsad = (requestData['maghsad'] ?? '---').toString();
    final String phone = (requestData['phone'] ?? '---').toString();
    final String description = (requestData['description'] ?? '---').toString();
    final String status = (requestData['status'] ?? 'open').toString();
    final String createdAt = (requestData['created_at'] ?? '').toString();
    final String comment = (requestData['comment'] ?? '---').toString();
    final String grade = (requestData['grade'] ?? '---').toString();

    // Check if user can rate:
    // allow all non-driver logical levels (1 and 2) when status is 'done'
    final int logicalLevel = getLogicalUserLevel(userLevel);
    final bool canRate = (logicalLevel == 1 || logicalLevel == 2) &&
        status == 'done' &&
        (grade == '---' || grade.isEmpty);

    // Check if user can complete task: same access rule but status 'assigned'
    final bool canCompleteTask =
        (logicalLevel == 1 || logicalLevel == 2) && status == 'assigned';

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
                        localizations.trd_title,
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
        textDirection: localizations.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _refreshRequestData,
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
              Text(
                localizations.trd_pieces,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pieces.isEmpty
                    ? [
                        Chip(
                          label: Text(localizations.trd_unknown),
                          backgroundColor: AppColors.lapisLazuli.withValues(
                            alpha: 0.06,
                          ),
                        ),
                      ]
                    : pieces
                          .map(
                            (p) => Chip(
                              label: Text(p.toString()),
                                backgroundColor: AppColors.lapisLazuli
                                    .withValues(alpha: 0.06),
                            ),
                          )
                          .toList(),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              _buildInfoItem(
                context,
                icon: Icons.location_on,
                title: localizations.trd_maghsad,
                value: maghsad,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.phone,
                title: localizations.trd_phone,
                value: phone,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                // Driver information section with all details
                _buildDriverInfoSection(context),
                SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                // Rating section: Average rating and customer's rating for this request
                _buildRatingSection(context),
                SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_description,
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
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_comment,
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
                    comment != '---' ? comment : localizations.trd_no_comment,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ),
                // Rating button for customers
                if (canRate) ...[
                  SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSubmittingRating ? null : _showRatingDialog,
                      icon: Icon(Icons.star),
                      label: Text(localizations.trd_rate_driver),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        '${localizations.trd_created_at} ${_formatDate(context, createdAt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.iranianGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Complete Task button for customers when status is 'assigned'
                if (canCompleteTask) ...[
                  SizedBox(height: ui.scale(base: 24, min: 20, max: 28)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _completeTask,
                      icon: isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(localizations.trd_complete_task),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverInfoSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final driverName = _getDriverDisplayName();
    final driverPhone = _getDriverPhone();
    final driverCode = _getDriverCode();
    final driverAddress = _getDriverAddress();
    final driverCity = _getDriverCity();

    if (driverInfo == null) {
      return _buildInfoItem(
        context,
        icon: Icons.person,
        title: localizations.trd_driver,
        value: localizations.trd_unknown,
      );
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 24, color: AppColors.lapisLazuli),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.trd_driver_info,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDriverInfoRow(
            context,
            Icons.person_outline,
            localizations.trd_driver_name,
            driverName,
          ),
          if (driverCode != '---') ...[
            const SizedBox(height: 12),
            _buildDriverInfoRow(
              context,
              Icons.badge,
              localizations.trd_driver_code,
              driverCode,
            ),
          ],
          if (driverPhone != '---') ...[
            const SizedBox(height: 12),
            _buildDriverInfoRow(
              context,
              Icons.phone,
              localizations.trd_driver_phone,
              driverPhone,
            ),
          ],
          if (driverCity != '---') ...[
            const SizedBox(height: 12),
            _buildDriverInfoRow(
              context,
              Icons.location_city,
              localizations.trd_driver_city,
              driverCity,
            ),
          ],
          if (driverAddress != '---') ...[
            const SizedBox(height: 12),
            _buildDriverInfoRow(
              context,
              Icons.home,
              localizations.trd_driver_address,
              driverAddress,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.lapisLazuli),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final avgRating = _getDriverAverageRating();

    // Get grade from requestData - can be int, string, or null
    final gradeValue = requestData['grade'];
    int? customerRating;

    if (gradeValue != null) {
      if (gradeValue is int) {
        customerRating = gradeValue >= 1 && gradeValue <= 5 ? gradeValue : null;
      } else if (gradeValue is String) {
        if (gradeValue.isNotEmpty &&
            gradeValue != '---' &&
            gradeValue != 'null') {
          customerRating = int.tryParse(gradeValue);
          if (customerRating != null &&
              (customerRating < 1 || customerRating > 5)) {
            customerRating = null;
          }
        }
      } else if (gradeValue is num) {
        final gradeInt = gradeValue.toInt();
        customerRating = gradeInt >= 1 && gradeInt <= 5 ? gradeInt : null;
      }
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, size: 24, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.trd_ratings,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Average rating
          if (avgRating != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.trd_average_rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.iranianGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < avgRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (customerRating != null) const SizedBox(height: 16),
          ],
          // Customer's rating for this request
          if (customerRating != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.trd_your_rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.iranianGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < customerRating!
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (avgRating == null) ...[
            Text(
              localizations.trd_no_ratings_yet,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                    Colors.black87,
              ),
            ),
          ],
        ],
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
