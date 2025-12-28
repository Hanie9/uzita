import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/ui_scale.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final descriptionController = TextEditingController();

  bool loading = false;
  String error = '';
  String? selectedSubjectType; // برای ذخیره موضوع انتخاب شده

  // برای شمارش کاراکترها
  int descriptionCharCount = 0;

  // محدودیت‌های کاراکتر
  final int maxDescriptionLength = 300;

  // لیست موضوعات
  final List<Map<String, String>> subjectTypes = [
    {'value': 'product_update', 'label_en': 'Product update', 'label_fa': 'به روزرسانی محصول'},
    {'value': 'part_update', 'label_en': 'Part update', 'label_fa': 'به روزرسانی قطعه'},
    {'value': 'feedback', 'label_en': 'Feedback and suggestions', 'label_fa': 'انتقاد و پیشنهاد'},
    {'value': 'other', 'label_en': 'Other', 'label_fa': 'سایر'},
  ];

  @override
  void initState() {
    super.initState();
    descriptionController.addListener(_updateDescriptionCount);
  }

  @override
  void dispose() {
    descriptionController.removeListener(_updateDescriptionCount);
    descriptionController.dispose();
    super.dispose();
  }

  void _updateDescriptionCount() {
    setState(() {
      descriptionCharCount = descriptionController.text.length;
    });
  }

  bool _isFormValid() {
    return selectedSubjectType != null &&
        descriptionController.text.trim().isNotEmpty &&
        descriptionController.text.length <= maxDescriptionLength;
  }

  String _getSubjectLabel(String value) {
    final localizations = AppLocalizations.of(context)!;
    
    switch (value) {
      case 'product_update':
        return localizations.ct_subject_product_update;
      case 'part_update':
        return localizations.ct_subject_part_update;
      case 'feedback':
        return localizations.ct_subject_feedback;
      case 'other':
        return localizations.ct_subject_other;
      default:
        return '';
    }
  }

  String _translateError(String error) {
    Map<String, String> errorTranslations = {
      'شما 3 تیکت بی پاسخ دارید. صبر کنید به تیکت های قبلی پاسخ داده شود.':
          AppLocalizations.of(context)!.ct_waiting_response_error,
      'همه فیلدها الزامی هستند.': AppLocalizations.of(context)!.ct_add_required,
      'خطا در ثبت تیکت.': AppLocalizations.of(context)!.ct_try_again_error,
    };

    return errorTranslations[error] ?? error;
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate() || !_isFormValid()) {
      setState(
        () => error = AppLocalizations.of(context)!.ct_add_required_correctly,
      );
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          error = AppLocalizations.of(context)!.ct_login_again;
          loading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/sendticket/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: utf8.encode(
          json.encode({
            'description': descriptionController.text.trim(),
            'subject_type': selectedSubjectType,
          }),
        ),
      );

      final String responseBody = utf8.decode(response.bodyBytes);
      final data = json.decode(responseBody);

      if (response.statusCode == 200) {
        // نمایش پیام موفقیت
        _showSuccessDialog(
          data['massage'] ??
              AppLocalizations.of(context)!.ct_send_ticket_successfully,
        );
      } else {
        setState(
          () => error = _translateError(
            data['error'] ?? AppLocalizations.of(context)!.ct_error_add_ticket,
          ),
        );
      }
    } catch (e) {
      setState(() => error = AppLocalizations.of(context)!.ct_error_connecting);
    }

    setState(() => loading = false);
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: Directionality.of(context),
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                UiScale(context).scale(base: 16, min: 12, max: 20),
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: UiScale(context).scale(base: 28, min: 20, max: 32),
                ),
                SizedBox(
                  width: UiScale(context).scale(base: 8, min: 6, max: 12),
                ),
                Text(
                  AppLocalizations.of(context)!.ct_send_ticket_successfully,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: TextStyle(
                fontSize: UiScale(context).scale(base: 14, min: 12, max: 16),
                height: 1.5,
                fontFamily: 'Vazir',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // بستن دیالوگ
                  Navigator.of(context).pop(); // برگشت به صفحه قبل
                },
                child: Text(
                  AppLocalizations.of(context)!.ct_I_got_it,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                    color: Colors.green[600],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: Directionality.of(context),
          child: AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                UiScale(context).scale(base: 16, min: 12, max: 20),
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Colors.orange[600],
                  size: UiScale(context).scale(base: 28, min: 20, max: 32),
                ),
                SizedBox(
                  width: UiScale(context).scale(base: 8, min: 6, max: 12),
                ),
                Text(
                  AppLocalizations.of(context)!.ct_send_submit,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
              ],
            ),
            content: Text(
              AppLocalizations.of(context)!.ct_are_you_sure,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: UiScale(context).scale(base: 14, min: 12, max: 16),
                fontFamily: 'Vazir',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)!.ct_cancle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontFamily: 'Vazir'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _submitTicket();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  AppLocalizations.of(context)!.ct_send,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
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
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.ct_send_new_ticket,
                        style: theme.appBarTheme.titleTextStyle,
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
                          height: UiScale(
                            context,
                          ).scale(base: screenHeight * 0.08, min: 28, max: 56),
                          width: UiScale(
                            context,
                          ).scale(base: screenHeight * 0.08, min: 28, max: 56),
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
          padding: EdgeInsets.fromLTRB(
            UiScale(context).scale(base: 20, min: 16, max: 24),
            UiScale(context).scale(base: 20, min: 16, max: 24),
            UiScale(context).scale(base: 20, min: 16, max: 24),
            UiScale(context).scale(base: 20, min: 16, max: 24) +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // کارت راهنمایی
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    UiScale(context).scale(base: 20, min: 16, max: 24),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[900]?.withValues(alpha: 0.2)
                        : Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? (Colors.blue[700] ?? Colors.blue).withValues(
                              alpha: 0.5,
                            )
                          : Color(0xFF2196F3).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          UiScale(context).scale(base: 8, min: 6, max: 10),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[700]
                              : Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(
                            UiScale(context).scale(base: 8, min: 6, max: 10),
                          ),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: UiScale(
                            context,
                          ).scale(base: 20, min: 16, max: 24),
                        ),
                      ),
                      SizedBox(
                        width: UiScale(
                          context,
                        ).scale(base: 16, min: 12, max: 20),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.ct_information,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[300]
                                    : Color(0xFF1976D2),
                                fontSize: UiScale(
                                  context,
                                ).scale(base: 16, min: 14, max: 18),
                                fontFamily: 'Vazir',
                              ),
                            ),
                            SizedBox(
                              height: UiScale(
                                context,
                              ).scale(base: 4, min: 2, max: 6),
                            ),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.ct_information_description,
                              style: TextStyle(
                                fontSize: UiScale(
                                  context,
                                ).scale(base: 13, min: 11, max: 15),
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[200]
                                    : Color(0xFF1976D2),
                                height: 1.4,
                                fontFamily: 'Vazir',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: UiScale(context).scale(base: 32, min: 24, max: 40),
                ),

                // فیلد انتخاب موضوع
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    UiScale(context).scale(base: 20, min: 16, max: 24),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              UiScale(context).scale(base: 6, min: 4, max: 8),
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(
                                UiScale(context).scale(base: 6, min: 4, max: 8),
                              ),
                            ),
                            child: Icon(
                              Icons.category,
                              color: Colors.white,
                              size: UiScale(
                                context,
                              ).scale(base: 16, min: 12, max: 20),
                            ),
                          ),
                          SizedBox(
                            width: UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16),
                          ),
                          Text(
                            AppLocalizations.of(context)!.ct_subject,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: UiScale(
                                    context,
                                  ).scale(base: 16, min: 14, max: 18),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Vazir',
                                ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: UiScale(
                          context,
                        ).scale(base: 16, min: 12, max: 20),
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedSubjectType,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.ct_subject_required,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[50],
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: UiScale(
                              context,
                            ).scale(base: 16, min: 12, max: 20),
                            vertical: UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16),
                          ),
                        ),
                        items: subjectTypes.map((subject) {
                          return DropdownMenuItem<String>(
                            value: subject['value'],
                            child: Text(
                              _getSubjectLabel(subject['value']!),
                              style: TextStyle(
                                fontFamily: 'Vazir',
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSubjectType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                              context,
                            )!.ct_subject_required;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: UiScale(context).scale(base: 20, min: 16, max: 24),
                ),

                // فیلد توضیحات
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    UiScale(context).scale(base: 20, min: 16, max: 24),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              UiScale(context).scale(base: 6, min: 4, max: 8),
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(
                                UiScale(context).scale(base: 6, min: 4, max: 8),
                              ),
                            ),
                            child: Icon(
                              Icons.description,
                              color: Colors.white,
                              size: UiScale(
                                context,
                              ).scale(base: 16, min: 12, max: 20),
                            ),
                          ),
                          SizedBox(
                            width: UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16),
                          ),
                          Text(
                            AppLocalizations.of(context)!.ct_description_ticket,
                            style: TextStyle(
                              fontSize: UiScale(
                                context,
                              ).scale(base: 16, min: 14, max: 18),
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.titleMedium?.color,
                              fontFamily: 'Vazir',
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: UiScale(
                                context,
                              ).scale(base: 8, min: 6, max: 12),
                              vertical: UiScale(
                                context,
                              ).scale(base: 4, min: 2, max: 6),
                            ),
                            decoration: BoxDecoration(
                              color: descriptionCharCount > maxDescriptionLength
                                  ? Colors.red[100]
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(
                                UiScale(
                                  context,
                                ).scale(base: 12, min: 8, max: 16),
                              ),
                            ),
                            child: Text(
                              '$descriptionCharCount/$maxDescriptionLength',
                              style: TextStyle(
                                fontSize: UiScale(
                                  context,
                                ).scale(base: 12, min: 10, max: 14),
                                color:
                                    descriptionCharCount > maxDescriptionLength
                                    ? Colors.red[700]
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontFamily: 'Vazir',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: UiScale(
                          context,
                        ).scale(base: 16, min: 12, max: 20),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 6,
                        maxLength: maxDescriptionLength,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.ct_description_ticket_hint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UiScale(context).scale(base: 12, min: 8, max: 16),
                            ),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: descriptionCharCount > maxDescriptionLength
                              ? Colors.red[50]
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50]),
                          counterText: '',
                          contentPadding: EdgeInsets.all(
                            UiScale(context).scale(base: 16, min: 12, max: 20),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(
                              context,
                            )!.ct_description_ticket_required;
                          }
                          if (value.length > maxDescriptionLength) {
                            return "${AppLocalizations.of(context)!.ct_description_max_length} $maxDescriptionLength ${AppLocalizations.of(context)!.ct_description_max_part_2}";
                          }
                          if (value.trim().length < 10) {
                            return AppLocalizations.of(
                              context,
                            )!.ct_description_ticket_min_length;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: UiScale(context).scale(base: 32, min: 24, max: 40),
                ),

                // دکمه ارسال
                SizedBox(
                  width: double.infinity,
                  height: UiScale(context).scale(base: 56, min: 48, max: 64),
                  child: ElevatedButton(
                    onPressed: loading || !_isFormValid()
                        ? null
                        : _showConfirmDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFormValid()
                          ? Color(0xFF4CAF50)
                          : Colors.grey[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UiScale(context).scale(base: 16, min: 12, max: 20),
                        ),
                      ),
                      elevation: _isFormValid() ? 4 : 0,
                      shadowColor: Color(0xFF4CAF50).withValues(alpha: 0.3),
                    ),
                    child: loading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: UiScale(
                                  context,
                                ).scale(base: 20, min: 16, max: 24),
                                height: UiScale(
                                  context,
                                ).scale(base: 20, min: 16, max: 24),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(
                                width: UiScale(
                                  context,
                                ).scale(base: 12, min: 8, max: 16),
                              ),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.ct_loading_sending,
                                style: TextStyle(
                                  fontSize: UiScale(
                                    context,
                                  ).scale(base: 16, min: 14, max: 18),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Vazir',
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.ct_send_ticket,
                                style: TextStyle(
                                  fontSize: UiScale(
                                    context,
                                  ).scale(base: 16, min: 14, max: 18),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Vazir',
                                ),
                              ),
                              SizedBox(
                                width: UiScale(
                                  context,
                                ).scale(base: 8, min: 6, max: 12),
                              ),
                              Icon(
                                Icons.send,
                                size: UiScale(
                                  context,
                                ).scale(base: 20, min: 16, max: 24),
                              ),
                            ],
                          ),
                  ),
                ),

                // نمایش خطا
                if (error.isNotEmpty) ...[
                  SizedBox(
                    height: UiScale(context).scale(base: 20, min: 16, max: 24),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(
                        UiScale(context).scale(base: 12, min: 8, max: 16),
                      ),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: UiScale(
                            context,
                          ).scale(base: 20, min: 16, max: 24),
                        ),
                        SizedBox(
                          width: UiScale(
                            context,
                          ).scale(base: 12, min: 8, max: 16),
                        ),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: UiScale(
                                context,
                              ).scale(base: 14, min: 12, max: 16),
                              height: 1.4,
                              fontFamily: 'Vazir',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(
                  height: UiScale(context).scale(base: 24, min: 20, max: 28),
                ),

                // نکات مهم
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    UiScale(context).scale(base: 20, min: 16, max: 24),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange[900]?.withValues(alpha: 0.2)
                        : Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(
                      UiScale(context).scale(base: 16, min: 12, max: 20),
                    ),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? (Colors.orange[700] ?? Colors.orange).withValues(
                              alpha: 0.5,
                            )
                          : Color(0xFFFF9800).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(
                              UiScale(context).scale(base: 6, min: 4, max: 8),
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.orange[700]
                                  : Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(
                                UiScale(context).scale(base: 6, min: 4, max: 8),
                              ),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: UiScale(
                                context,
                              ).scale(base: 16, min: 12, max: 20),
                            ),
                          ),
                          SizedBox(
                            width: UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16),
                          ),
                          Text(
                            AppLocalizations.of(context)!.ct_important_notes,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.orange[300]
                                  : Color(0xFFE65100),
                              fontSize: UiScale(
                                context,
                              ).scale(base: 16, min: 14, max: 18),
                              fontFamily: 'Vazir',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: UiScale(
                          context,
                        ).scale(base: 12, min: 8, max: 16),
                      ),
                      Text(
                        "${AppLocalizations.of(context)!.ct_important_notes_part_1}\n${AppLocalizations.of(context)!.ct_important_notes_part_2}\n${AppLocalizations.of(context)!.ct_important_notes_part_3}",
                        style: TextStyle(
                          fontSize: UiScale(
                            context,
                          ).scale(base: 13, min: 11, max: 15),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.orange[200]
                              : Color(0xFFE65100),
                          height: 1.5,
                          fontFamily: 'Vazir',
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
}
