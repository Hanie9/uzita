import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();

  bool loading = false;
  String error = '';

  // برای شمارش کاراکترها
  int titleCharCount = 0;
  int descriptionCharCount = 0;

  // محدودیت‌های کاراکتر
  final int maxTitleLength = 100;
  final int maxDescriptionLength = 300;

  @override
  void initState() {
    super.initState();
    titleController.addListener(_updateTitleCount);
    descriptionController.addListener(_updateDescriptionCount);
  }

  @override
  void dispose() {
    titleController.removeListener(_updateTitleCount);
    descriptionController.removeListener(_updateDescriptionCount);
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _updateTitleCount() {
    setState(() {
      titleCharCount = titleController.text.length;
    });
  }

  void _updateDescriptionCount() {
    setState(() {
      descriptionCharCount = descriptionController.text.length;
    });
  }

  bool _isFormValid() {
    return titleController.text.trim().isNotEmpty &&
        descriptionController.text.trim().isNotEmpty &&
        titleController.text.length <= maxTitleLength &&
        descriptionController.text.length <= maxDescriptionLength;
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
            'title': titleController.text.trim(),
            'description': descriptionController.text.trim(),
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
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 28),
                SizedBox(width: 8),
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
              style: TextStyle(fontSize: 14, height: 1.5, fontFamily: 'Vazir'),
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
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.orange[600], size: 28),
                SizedBox(width: 8),
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
                fontSize: 14,
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // کارت راهنمایی
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[900]?.withValues(alpha: 0.2)
                        : Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(16),
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
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[700]
                              : Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
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
                                fontSize: 16,
                                fontFamily: 'Vazir',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.ct_information_description,
                              style: TextStyle(
                                fontSize: 13,
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

                SizedBox(height: 32),

                // فیلد عنوان تیکت
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
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
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.title,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.ct_title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Vazir',
                                ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: titleCharCount > maxTitleLength
                                  ? Colors.red[100]
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$titleCharCount/$maxTitleLength',
                              style: TextStyle(
                                fontSize: 12,
                                color: titleCharCount > maxTitleLength
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
                      SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        maxLength: maxTitleLength,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.ct_title_example,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: titleCharCount > maxTitleLength
                              ? Colors.red[50]
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50]),
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return AppLocalizations.of(
                              context,
                            )!.ct_add_required;
                          }
                          if (value.length > maxTitleLength) {
                            return "${AppLocalizations.of(context)!.ct_max_part_1} $maxTitleLength ${AppLocalizations.of(context)!.ct_max_part_2}";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // فیلد توضیحات
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
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
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.description,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.ct_description_ticket,
                            style: TextStyle(
                              fontSize: 16,
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
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: descriptionCharCount > maxDescriptionLength
                                  ? Colors.red[100]
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[800]
                                        : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$descriptionCharCount/$maxDescriptionLength',
                              style: TextStyle(
                                fontSize: 12,
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
                      SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 6,
                        maxLength: maxDescriptionLength,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.ct_description_ticket_hint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          filled: true,
                          fillColor: descriptionCharCount > maxDescriptionLength
                              ? Colors.red[50]
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50]),
                          counterText: '',
                          contentPadding: EdgeInsets.all(16),
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

                SizedBox(height: 32),

                // دکمه ارسال
                SizedBox(
                  width: double.infinity,
                  height: 56,
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _isFormValid() ? 4 : 0,
                      shadowColor: Color(0xFF4CAF50).withValues(alpha: 0.3),
                    ),
                    child: loading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.ct_loading_sending,
                                style: TextStyle(
                                  fontSize: 16,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Vazir',
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.send, size: 20),
                            ],
                          ),
                  ),
                ),

                // نمایش خطا
                if (error.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[600],
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                              height: 1.4,
                              fontFamily: 'Vazir',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 24),

                // نکات مهم
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange[900]?.withValues(alpha: 0.2)
                        : Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
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
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.orange[700]
                                  : Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.ct_important_notes,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.orange[300]
                                  : Color(0xFFE65100),
                              fontSize: 16,
                              fontFamily: 'Vazir',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "${AppLocalizations.of(context)!.ct_important_notes_part_1}\n${AppLocalizations.of(context)!.ct_important_notes_part_2}\n${AppLocalizations.of(context)!.ct_important_notes_part_3}",
                        style: TextStyle(
                          fontSize: 13,
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
