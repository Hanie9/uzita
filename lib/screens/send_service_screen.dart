import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'dart:convert';

import '../services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';

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

  String? selectedTime;
  String? selectedPiece;
  List<String> timeOptions = [];
  List<String> pieceOptions = ['part1', 'part2', 'part3', 'part4', 'part5'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
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
    if (!_formKey.currentState!.validate() ||
        selectedTime == null ||
        selectedPiece == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.sss_add_required)),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final timeInMinutes = getTimeInMinutes(selectedTime!);
      final otherCost = int.tryParse(_otherCostController.text) ?? 0;

      final response = await http.post(
        Uri.parse('$baseUrl5/sendservice/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'time': timeInMinutes,
          'sayer_hazine': otherCost,
          'name_piece': selectedPiece,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
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
                          height: screenHeight * 0.08,
                          width: screenHeight * 0.08,
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
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(bottom: 24, top: 8),
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
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lapisLazuli.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(height: 18),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.build_circle,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.sss_send_service_request_form,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textDirection: Directionality.of(context),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppColors.lapisLazuli.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(20),
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
                        SizedBox(height: 8),
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
                        SizedBox(height: 20),
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
                        SizedBox(height: 8),
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
                              Icons.description,
                              color: AppColors.lapisLazuli,
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
                        // Piece Selection
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
                        SizedBox(height: 8),
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
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
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
                              Icons.settings,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          items: pieceOptions.map((String part) {
                            return DropdownMenuItem<String>(
                              value: part,
                              child: Text(
                                part,
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
                        SizedBox(height: 20),
                        // Time Selection
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
                        SizedBox(height: 8),
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
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
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
                        // Other Costs Field
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
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
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
                        SizedBox(height: 32),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : submitRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.lapisLazuli,
                              padding: EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            icon: isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Icon(Icons.send, color: Colors.white),
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
                                fontSize: 16,
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _otherCostController.dispose();
    super.dispose();
  }
}
