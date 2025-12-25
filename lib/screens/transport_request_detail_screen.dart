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

  @override
  void initState() {
    super.initState();
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
    final driver = widget.request['driver'];
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

  void _loadExistingRating() {
    final comment = widget.request['comment'];
    final grade = widget.request['grade'];

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
    final avgRating =
        driverInfo!['average_rating'] ?? driverInfo!['avg_rating'];
    if (avgRating == null) return null;
    if (avgRating is num) {
      return avgRating.toDouble();
    }
    final avgRatingStr = avgRating.toString();
    return double.tryParse(avgRatingStr);
  }

  Future<void> _submitRating() async {
    if (selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.trd_grade_required),
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
        throw Exception('Token is missing. Please login again.');
      }

      final requestId = widget.request['id']?.toString() ?? '';
      if (requestId.isEmpty) {
        throw Exception('Request ID is missing');
      }

      await SessionManager().onNetworkRequest();

      final Map<String, dynamic> requestBody = {'grade': selectedGrade!};

      if (_commentController.text.trim().isNotEmpty) {
        requestBody['comment'] = _commentController.text.trim();
      }

      final url =
          'https://device-control.liara.run/api/transport/request/$requestId/rate';
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

      if (!mounted) return;

      setState(() {
        isSubmittingRating = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.trd_rating_submitted_success,
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Update local data
        widget.request['grade'] = selectedGrade.toString();
        widget.request['comment'] = _commentController.text.trim();

        // Navigate back with success
        Navigator.pop(context, true);
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

    final List<dynamic> pieces = (widget.request['pieces'] as List?) ?? [];
    final String maghsad = (widget.request['maghsad'] ?? '---').toString();
    final String phone = (widget.request['phone'] ?? '---').toString();
    final String description = (widget.request['description'] ?? '---')
        .toString();
    final String status = (widget.request['status'] ?? 'open').toString();
    final String createdAt = (widget.request['created_at'] ?? '').toString();
    final String comment = (widget.request['comment'] ?? '---').toString();
    final String grade = (widget.request['grade'] ?? '---').toString();

    // Check if user can rate (customers: level 1, 2, 4, 6 and status is 'done')
    final bool canRate =
        (userLevel == 1 ||
            userLevel == 2 ||
            userLevel == 4 ||
            userLevel == 6) &&
        status == 'done' &&
        (grade == '---' || grade.isEmpty);

    // Check if user can comment/rate (customers: level 1, 2, 4, 6 and status is 'done')
    final bool canCommentOrRate =
        (userLevel == 1 ||
            userLevel == 2 ||
            userLevel == 4 ||
            userLevel == 6) &&
        status == 'done';

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
        child: SingleChildScrollView(
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                              backgroundColor: AppColors.lapisLazuli.withValues(
                                alpha: 0.06,
                              ),
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
              _buildRatingSection(context, grade),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_description,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              // Comment and Rating button at the bottom for customers
              if (canCommentOrRate) ...[
                SizedBox(height: ui.scale(base: 24, min: 20, max: 28)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSubmittingRating ? null : _showRatingDialog,
                    icon: Icon(
                      grade != '---' && grade.isNotEmpty
                          ? Icons.edit
                          : Icons.star,
                    ),
                    label: Text(
                      grade != '---' && grade.isNotEmpty
                          ? localizations.trd_edit_rating
                          : localizations.trd_rate_and_comment,
                    ),
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

  Widget _buildRatingSection(BuildContext context, String grade) {
    final localizations = AppLocalizations.of(context)!;
    final avgRating = _getDriverAverageRating();
    final customerRating = (grade != '---' && grade.isNotEmpty)
        ? int.tryParse(grade)
        : null;

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
                          const SizedBox(width: 8),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color ??
                                  Colors.black87,
                            ),
                          ),
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
                              index < customerRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            '$customerRating / 5',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color ??
                                  Colors.black87,
                            ),
                          ),
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
