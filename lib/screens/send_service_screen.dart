import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show utf8;
import 'package:flutter/services.dart';

import '../services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class SendServiceScreen extends StatefulWidget {
  const SendServiceScreen({super.key});

  @override
  State<SendServiceScreen> createState() => _SendServiceScreenState();
}

class _SendServiceScreenState extends State<SendServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _otherCostController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _serialNumberController = TextEditingController();

  String? selectedTime;
  String? selectedPiece;
  String? selectedUrgency;
  List<String> selectedSubjects = [];
  List<String> timeOptions = [];
  List<String> pieceOptions = [];
  int userLevel = 3;

  /// Subject type values for service request (level 1 & 3). Labels from localization.
  static const List<String> subjectTypeValues = [
    'lock',
    'password',
    'learn',
    'reopening',
  ];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPieces();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 3;
    });
  }

  Future<void> _fetchPieces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return;

      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl5/listpieces'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          setState(() {
            pieceOptions = data
                .map((item) => item['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList();
          });
        }
      }
    } catch (e) {
      // If API fails, keep empty list - pieces will be loaded from API only
      if (mounted) {
        setState(() {
          pieceOptions = [];
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppLocalizations.of(context)!;
    final newOptions = [
      loc.sss_half_hour,
      loc.sss_one_hour,
      loc.sss_two_hour,
      loc.sss_three_hour,
      loc.sss_four_hour,
      loc.sss_five_hour,
      loc.sss_six_hour,
      loc.sss_seven_hour,
      loc.sss_eight_hour,
      loc.sss_nine_hour,
      loc.sss_ten_hour,
    ];
    if (!listEquals(timeOptions, newOptions)) {
      setState(() {
        timeOptions = newOptions;
      });
    }
  }

  int getTimeInMinutes(String timeOption) {
    // Get localized values for comparison
    final localizations = AppLocalizations.of(context)!;

    if (timeOption == localizations.sss_half_hour) return 30;
    if (timeOption == localizations.sss_one_hour) return 60;
    if (timeOption == localizations.sss_two_hour) return 120;
    if (timeOption == localizations.sss_three_hour) return 180;
    if (timeOption == localizations.sss_four_hour) return 240;
    if (timeOption == localizations.sss_five_hour) return 300;
    if (timeOption == localizations.sss_six_hour) return 360;
    if (timeOption == localizations.sss_seven_hour) return 420;
    if (timeOption == localizations.sss_eight_hour) return 480;
    if (timeOption == localizations.sss_nine_hour) return 540;
    if (timeOption == localizations.sss_ten_hour) return 600;

    return 60; // default
  }

  Future<void> submitRequest() async {
    // Validate based on user level
    if (userLevel == 1 || userLevel == 3) {
      // For level 1 and 3: validate title, description, address, phone, urgency, subject
      if (!_formKey.currentState!.validate() ||
          selectedUrgency == null ||
          selectedSubjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sss_add_required),
          ),
        );
        return;
      }
    } else {
      // For other levels: validate title, description, time, piece
      if (!_formKey.currentState!.validate() ||
          selectedTime == null ||
          selectedPiece == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sss_add_required),
          ),
        );
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      Map<String, dynamic> requestBody;

      if (userLevel == 1 || userLevel == 3) {
        // For level 1 and 3: send title, description, address, phone, urgency, subjects[]
        requestBody = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'address': _addressController.text,
          'phone': _phoneController.text,
          'urgency': selectedUrgency,
          'subjects': selectedSubjects,
        };
        // Add serial_number if provided (optional)
        if (_serialNumberController.text.trim().isNotEmpty) {
          requestBody['serial_number'] = _serialNumberController.text.trim();
        }
      } else {
        // For other levels: send title, description, time, sayer_hazine, name_piece
        final timeInMinutes = getTimeInMinutes(selectedTime!);
        final otherCost = int.tryParse(_otherCostController.text) ?? 0;
        requestBody = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'time': timeInMinutes,
          'sayer_hazine': otherCost,
          'name_piece': selectedPiece,
        };
        // Add serial_number if provided (optional)
        if (_serialNumberController.text.trim().isNotEmpty) {
          requestBody['serial_number'] = _serialNumberController.text.trim();
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl5/sendservice/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final hazine = responseData['hazine'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.lapisLazuli,
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.sss_successfully,
                  style: TextStyle(
                    color: AppColors.lapisLazuli,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.sss_submit_successfully,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hazine != null && (userLevel != 1 && userLevel != 3)) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bronzeGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.sss_total_cost,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.iranianGray,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$hazine ${AppLocalizations.of(context)!.sss_tooman}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.maroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true); // Return to list and refresh
                },
                child: Text(
                  AppLocalizations.of(context)!.sss_ok,
                  style: TextStyle(color: AppColors.lapisLazuli, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorData['error'] ??
                  AppLocalizations.of(context)!.sss_error_send_request,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sss_error_connecting),
        ),
      );
    }
  }

  Future<void> _scanSerialNumber() async {
    try {
      var permissionStatus = await Permission.camera.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.camera.request();
      }
      if (!permissionStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.dls_camera_permission_denied,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (permissionStatus.isPermanentlyDenied && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                AppLocalizations.of(context)!.dls_camera_permission_denied,
              ),
              content: Text(
                AppLocalizations.of(
                  context,
                )!.dls_camera_permission_denied_description,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppLocalizations.of(context)!.login_cancle),
                ),
                TextButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(AppLocalizations.of(context)!.login_settings),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => _SerialScannerPage()),
        );
        if (result != null && result is String) {
          setState(() {
            _serialNumberController.text = result;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.dls_error_scanning),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final ui = UiScale(context);

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
                children: [
                  // Left side - Back button and title
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
                        AppLocalizations.of(context)!.sss_send_service_request,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
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
      body: Directionality(
        textDirection:
            Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header (now scrollable)
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  bottom: ui.scale(base: 16, min: 12, max: 20),
                  top: ui.scale(base: 8, min: 6, max: 12),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lapisLazuli,
                      AppColors.lapisLazuli.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                      ui.scale(base: 20, min: 16, max: 24),
                    ),
                    bottomRight: Radius.circular(
                      ui.scale(base: 20, min: 16, max: 24),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.10),
                      blurRadius: ui.scale(base: 12, min: 8, max: 16),
                      offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                    Container(
                      padding: EdgeInsets.all(
                        ui.scale(base: 12, min: 10, max: 16),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.build_circle,
                        size: ui.scale(base: 32, min: 24, max: 40),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: ui.scale(base: 6, min: 4, max: 8)),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.sss_send_service_request_form,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ui.scale(base: 16, min: 14, max: 18),
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 6, min: 4, max: 8)),
                  ],
                ),
              ),
              // Form
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28) +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(
                        ui.scale(base: 20, min: 12, max: 24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppColors.lapisLazuli.withValues(alpha: 0.06),
                          blurRadius: ui.scale(base: 12, min: 8, max: 16),
                          offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(
                      ui.scale(base: 20, min: 14, max: 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Field
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.sss_send_service_request_form_title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                        TextFormField(
                          controller: _titleController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.sss_send_service_request_form_title_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.title,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.sss_add_service_request_title_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),
                        // Subject (موضوع) - below title for level 1 and 3
                        if (userLevel == 1 || userLevel == 3) ...[
                          Text(
                            AppLocalizations.of(context)!.sss_subject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          Wrap(
                            spacing: ui.scale(base: 8, min: 6, max: 12),
                            runSpacing: ui.scale(base: 8, min: 6, max: 12),
                            children: subjectTypeValues.map((value) {
                              final loc = AppLocalizations.of(context)!;
                              final label = value == 'lock'
                                  ? loc.sss_subject_lock
                                  : value == 'password'
                                  ? loc.sss_subject_password
                                  : value == 'learn'
                                  ? loc.sss_subject_learn
                                  : loc.sss_subject_reopening;
                              final isSelected = selectedSubjects.contains(
                                value,
                              );
                              return FilterChip(
                                label: Text(
                                  label,
                                  textDirection: Directionality.of(context),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedSubjects = List.from(
                                        selectedSubjects,
                                      )..add(value);
                                    } else {
                                      selectedSubjects = selectedSubjects
                                          .where((s) => s != value)
                                          .toList();
                                    }
                                  });
                                },
                                selectedColor: AppColors.lapisLazuli.withValues(
                                  alpha: 0.25,
                                ),
                                checkmarkColor: AppColors.lapisLazuli,
                              );
                            }).toList(),
                          ),
                          SizedBox(
                            height: ui.scale(base: 20, min: 14, max: 24),
                          ),
                        ],
                        // Description Field
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.sss_send_service_request_form_description,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                        TextFormField(
                          controller: _descriptionController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.sss_send_service_request_form_description_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.description,
                              color: AppColors.lapisLazuli,
                              size: 20,
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 20,
                              maxHeight: 20,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.only(
                              left:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? ui.scale(base: 12, min: 8, max: 16)
                                  : ui.scale(base: 4, min: 2, max: 8),
                              right:
                                  Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? ui.scale(base: 4, min: 2, max: 8)
                                  : ui.scale(base: 12, min: 8, max: 16),
                              top: ui.scale(base: 16, min: 12, max: 20),
                              bottom: ui.scale(base: 16, min: 12, max: 20),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.sss_add_service_request_description_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        // Serial Number Field (optional for all levels)
                        Text(
                          AppLocalizations.of(context)!.dls_serial_number,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                        TextFormField(
                          controller: _serialNumberController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.dls_serial_number,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.qr_code,
                              color: AppColors.lapisLazuli,
                            ),
                            suffixIcon: IconButton(
                              tooltip: AppLocalizations.of(context)!.dls_scan,
                              icon: Icon(Icons.qr_code_scanner),
                              color: AppColors.lapisLazuli,
                              onPressed: _scanSerialNumber,
                            ),
                          ),
                        ),
                        SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),
                        // Conditional fields based on user level
                        if (userLevel == 1 || userLevel == 3) ...[
                          // Address Field (for level 1 and 3)
                          Text(
                            AppLocalizations.of(context)!.sss_address,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          TextFormField(
                            controller: _addressController,
                            textDirection: Directionality.of(context),
                            textAlign:
                                Directionality.of(context) == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_address_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.location_on,
                                color: AppColors.lapisLazuli,
                                size: 20,
                              ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 20,
                                maxHeight: 20,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.only(
                                left:
                                    Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? ui.scale(base: 12, min: 8, max: 16)
                                    : ui.scale(base: 4, min: 2, max: 8),
                                right:
                                    Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? ui.scale(base: 4, min: 2, max: 8)
                                    : ui.scale(base: 12, min: 8, max: 16),
                                top: ui.scale(base: 16, min: 12, max: 20),
                                bottom: ui.scale(base: 16, min: 12, max: 20),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_address_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(
                            height: ui.scale(base: 20, min: 14, max: 24),
                          ),
                          // Phone Field (for level 1 and 3)
                          Text(
                            AppLocalizations.of(context)!.sss_phone,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          TextFormField(
                            controller: _phoneController,
                            textDirection: Directionality.of(context),
                            textAlign:
                                Directionality.of(context) == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_phone_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.phone,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_phone_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(
                            height: ui.scale(base: 20, min: 14, max: 24),
                          ),
                          // Urgency Field (for level 1 and 3)
                          Text(
                            AppLocalizations.of(context)!.sss_urgency,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          DropdownButtonFormField<String>(
                            value: selectedUrgency,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_urgency_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.priority_high,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: 'normal',
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.sss_urgency_normal,
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'urgent',
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.sss_urgency_urgent,
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'very_urgent',
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.sss_urgency_very_urgent,
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedUrgency = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_urgency_error;
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          // Piece Selection (for other levels)
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.sss_add_service_request_piece,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          DropdownButtonFormField<String>(
                            value: selectedPiece,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_choose_service_request_piece_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.settings,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: ui.scale(base: 18, min: 16, max: 20),
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                            items: pieceOptions.map((String part) {
                              return DropdownMenuItem<String>(
                                value: part,
                                child: Text(
                                  part,
                                  style: TextStyle(
                                    fontSize: ui.scale(
                                      base: 18,
                                      min: 16,
                                      max: 20,
                                    ),
                                  ),
                                  textDirection: Directionality.of(context),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedPiece = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_add_service_request_piece_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(
                            height: ui.scale(base: 20, min: 14, max: 24),
                          ),
                          // Time Selection (for other levels)
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.sss_add_service_request_time,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                          DropdownButtonFormField<String>(
                            value: selectedTime,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_add_service_request_time_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.access_time,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                            items: timeOptions.map((String time) {
                              return DropdownMenuItem<String>(
                                value: time,
                                child: Text(
                                  time,
                                  textDirection: Directionality.of(context),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedTime = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_add_service_request_time_error;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          // Other Costs Field (for other levels)
                          Text(
                            AppLocalizations.of(context)!.sss_other_costs,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lapisLazuli,
                            ),
                            textDirection: Directionality.of(context),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _otherCostController,
                            textDirection: Directionality.of(context),
                            textAlign:
                                Directionality.of(context) == TextDirection.rtl
                                ? TextAlign.right
                                : TextAlign.left,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.sss_other_costs_hint,
                              hintStyle: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[800]
                                  : AppColors.lapisLazuli.withValues(
                                      alpha: 0.04,
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppColors.lapisLazuli,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.monetization_on,
                                color: AppColors.lapisLazuli,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_other_costs_error;
                              }
                              if (int.tryParse(value) == null) {
                                return AppLocalizations.of(
                                  context,
                                )!.sss_other_costs_error_number;
                              }
                              return null;
                            },
                          ),
                        ],
                        SizedBox(height: ui.scale(base: 32, min: 20, max: 36)),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.lapisLazuli,
                              padding: EdgeInsets.symmetric(
                                vertical: ui.scale(base: 18, min: 14, max: 22),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                              ),
                              elevation: 4,
                            ),
                            icon: isLoading
                                ? SizedBox(
                                    width: ui.scale(base: 24, min: 18, max: 28),
                                    height: ui.scale(
                                      base: 24,
                                      min: 18,
                                      max: 28,
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      strokeWidth: ui.scale(
                                        base: 2.5,
                                        min: 2.0,
                                        max: 3.0,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: ui.scale(base: 20, min: 16, max: 24),
                                  ),
                            label: Text(
                              isLoading
                                  ? AppLocalizations.of(
                                      context,
                                    )!.sss_loading_sending
                                  : AppLocalizations.of(
                                      context,
                                    )!.sss_send_service_request_form_submit,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ui.scale(base: 16, min: 14, max: 18),
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: Directionality.of(context),
                            ),
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
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _otherCostController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }
}

class _SerialScannerPage extends StatefulWidget {
  @override
  State<_SerialScannerPage> createState() => _SerialScannerPageState();
}

class _SerialScannerPageState extends State<_SerialScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: true,
    facing: CameraFacing.back,
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
    ],
  );
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller.start().catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dls_scan_barcode),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.dls_on_and_off_flash,
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.dls_switch_camera,
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_handled) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final raw = (barcodes.first.rawValue ?? '').trim();
                  if (raw.isNotEmpty) {
                    _handled = true;
                    Navigator.of(context).pop(raw);
                  }
                }
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  borderColor: AppColors.lapisLazuli,
                  overlayColor: theme.colorScheme.surface.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.dls_scan_hint,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      )!.dls_scan_from_gallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _pickFromGallery,
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.dls_scan_from_file,
                      icon: const Icon(Icons.attach_file),
                      onPressed: _pickFromFiles,
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.dls_close_scan,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final result = await _controller.analyzeImage(picked.path);
      final bytes = await picked.readAsBytes();
      String? raw;
      if (result != null && result.barcodes.isNotEmpty) {
        raw = (result.barcodes.first.rawValue ?? '').trim();
      }
      await _showImageResult(bytes, raw?.isNotEmpty == true ? raw : null);
    } catch (_) {}
  }

  Future<void> _pickFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final path = res?.files.single.path;
      if (path == null) return;
      final result = await _controller.analyzeImage(path);
      Uint8List? bytes = res!.files.single.bytes;
      bytes ??= await File(res.files.single.path!).readAsBytes();
      String? raw;
      if (result != null && result.barcodes.isNotEmpty) {
        raw = (result.barcodes.first.rawValue ?? '').trim();
      }
      await _showImageResult(bytes, raw?.isNotEmpty == true ? raw : null);
    } catch (_) {}
  }

  Future<void> _showImageResult(Uint8List imageBytes, String? code) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    height: MediaQuery.of(ctx).size.height * 0.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  code == null
                      ? AppLocalizations.of(context)!.dls_no_barcode_found
                      : '${AppLocalizations.of(context)!.dls_barcode_found}: $code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: code == null ? Colors.red : AppColors.lapisLazuli,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          AppLocalizations.of(context)!.dls_close_scan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: code == null
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                _handled = true;
                                Navigator.of(context).pop(code);
                              },
                        child: Text(AppLocalizations.of(context)!.dls_use_code),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  _ScannerOverlayPainter({
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final rect = Offset.zero & size;
    final double width = size.width * 0.75;
    final double height = width;
    final Rect hole = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: height,
    );

    final overlayPath = Path()..addRect(rect);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlayPath, holePath),
      paint,
    );

    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const double cornerLen = 28;
    const double radius = 16;

    _drawCorner(
      canvas,
      hole.topLeft,
      cornerLen,
      CornerPosition.topLeft,
      cornerPaint,
      radius,
    );
    _drawCorner(
      canvas,
      hole.topRight,
      cornerLen,
      CornerPosition.topRight,
      cornerPaint,
      radius,
    );
    _drawCorner(
      canvas,
      hole.bottomLeft,
      cornerLen,
      CornerPosition.bottomLeft,
      cornerPaint,
      radius,
    );
    _drawCorner(
      canvas,
      hole.bottomRight,
      cornerLen,
      CornerPosition.bottomRight,
      cornerPaint,
      radius,
    );
  }

  void _drawCorner(
    Canvas canvas,
    Offset corner,
    double len,
    CornerPosition pos,
    Paint paint,
    double radius,
  ) {
    final path = Path();
    switch (pos) {
      case CornerPosition.topLeft:
        path.moveTo(corner.dx, corner.dy + radius);
        path.lineTo(corner.dx, corner.dy + len);
        path.moveTo(corner.dx + radius, corner.dy);
        path.lineTo(corner.dx + len, corner.dy);
        break;
      case CornerPosition.topRight:
        path.moveTo(corner.dx, corner.dy + radius);
        path.lineTo(corner.dx, corner.dy + len);
        path.moveTo(corner.dx - radius, corner.dy);
        path.lineTo(corner.dx - len, corner.dy);
        break;
      case CornerPosition.bottomLeft:
        path.moveTo(corner.dx, corner.dy - radius);
        path.lineTo(corner.dx, corner.dy - len);
        path.moveTo(corner.dx + radius, corner.dy);
        path.lineTo(corner.dx + len, corner.dy);
        break;
      case CornerPosition.bottomRight:
        path.moveTo(corner.dx, corner.dy - radius);
        path.lineTo(corner.dx, corner.dy - len);
        path.moveTo(corner.dx - radius, corner.dy);
        path.lineTo(corner.dx - len, corner.dy);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor;
  }
}

enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }
