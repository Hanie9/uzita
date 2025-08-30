import 'package:flutter/material.dart';
import 'package:uzita/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/otp_verify_pass_screen.dart';
import 'package:uzita/services.dart';
import 'dart:convert';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';

final String baseUrl2 = apiBaseUrl;

Widget buildPasswordChangeForm({
  required String title,
  required Map<String, TextEditingController> controllers,
  required Function() onSubmit,
  required String error,
  required bool loading,
  required bool isFormValid,
}) {
  return Builder(
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;

      final logoHeight = screenHeight * 0.25;
      final svgHeight = logoHeight * 1.2;
      final svgWidth = screenWidth * 0.95;
      // final spacingAfterLogo = screenHeight * 0.02;

      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: UiScale(
                    context,
                  ).scale(base: 16, min: 12, max: 20),
                ),
                child: Row(
                  children: [
                    // Left side - Back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          AppLocalizations.of(context)!.editpassword_title,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.grey[800],
                            fontSize: UiScale(
                              context,
                            ).scale(base: 18, min: 16, max: 20),
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
                            height: UiScale(context).scale(
                              base: screenHeight * 0.08,
                              min: 28,
                              max: 56,
                            ),
                            width: UiScale(context).scale(
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
        resizeToAvoidBottomInset: true,
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Column(
                          children: [
                            // REMOVE the Row with the logo from the form body
                            SizedBox(
                              height:
                                  logoHeight +
                                  UiScale(
                                    context,
                                  ).scale(base: 20, min: 16, max: 24),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Main logo image at the top
                                  Positioned(
                                    top: -logoHeight * 0.3,
                                    child: Image.asset(
                                      'assets/biokaveh.png',
                                      height: svgHeight,
                                      width: svgWidth,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  // ELARRO text in gold/bronze in the middle
                                  Positioned(
                                    top: logoHeight * 0.44,
                                    child: Builder(
                                      builder: (_) {
                                        final double elarroFontSize =
                                            (screenWidth * 0.08)
                                                .clamp(22.0, 32.0)
                                                .toDouble();
                                        return Text(
                                          'ELARRO',
                                          style: TextStyle(
                                            fontSize: elarroFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.lapisLazuli,
                                            letterSpacing: UiScale(
                                              context,
                                            ).scale(base: 4, min: 3, max: 5),
                                            fontFamily: 'Nasalization',
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // BIOKAVEH text in black at the bottom
                                  Positioned(
                                    top:
                                        (logoHeight * 0.38) +
                                        ((screenWidth * 0.08)
                                                .clamp(22.0, 32.0)
                                                .toDouble() *
                                            1.25) +
                                        UiScale(
                                          context,
                                        ).scale(base: 6, min: 4, max: 8),
                                    child: Text(
                                      'BIOKAVEH',
                                      style: TextStyle(
                                        fontSize: (screenWidth * 0.045)
                                            .clamp(16.0, 22.0)
                                            .toDouble(),
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: UiScale(
                                          context,
                                        ).scale(base: 2, min: 1, max: 3),
                                        fontFamily: 'Nasalization',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.06),

                            TextField(
                              controller: controllers['newPassword'],
                              obscureText: true,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: screenWidth * 0.035),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(
                                  context,
                                )!.editpassword_new_password,
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : const Color.fromARGB(255, 99, 97, 97),
                                  fontSize: screenWidth * 0.04,
                                ),
                                hintTextDirection: TextDirection.rtl,
                                suffixIcon: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : const Color.fromARGB(255, 80, 77, 77),
                                    size: screenHeight * 0.035,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.035,
                                  vertical: screenHeight * 0.018,
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.015),

                            TextField(
                              controller: controllers['confirmPassword'],
                              obscureText: true,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: screenWidth * 0.035),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(
                                  context,
                                )!.editpassword_confirm_password,
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : const Color.fromARGB(255, 99, 97, 97),
                                  fontSize: screenWidth * 0.04,
                                ),
                                hintTextDirection: TextDirection.rtl,
                                suffixIcon: Padding(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : const Color.fromARGB(255, 80, 77, 77),
                                    size: screenHeight * 0.035,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.035,
                                  vertical: screenHeight * 0.018,
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.03),

                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  UiScale(
                                    context,
                                  ).scale(base: 15, min: 12, max: 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isFormValid
                                        ? AppColors.emerald.withValues(
                                            alpha: 0.5,
                                          )
                                        : AppColors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: screenHeight * 0.062,
                                child: AbsorbPointer(
                                  absorbing: loading || !isFormValid,
                                  child: ElevatedButton(
                                    onPressed: loading || !isFormValid
                                        ? null
                                        : onSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFormValid
                                          ? AppColors.emerald
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          UiScale(
                                            context,
                                          ).scale(base: 8, min: 6, max: 10),
                                        ),
                                      ),
                                      elevation: 1,
                                    ),
                                    child: loading
                                        ? SizedBox(
                                            height: screenHeight * 0.022,
                                            width: screenHeight * 0.022,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.editpassword_change_password,
                                              style: TextStyle(
                                                fontSize: UiScale(context)
                                                    .scale(
                                                      base: screenWidth * 0.08,
                                                      min: 16,
                                                      max: 20,
                                                    ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.025),

                            if (error.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(
                                    UiScale(
                                      context,
                                    ).scale(base: 8, min: 6, max: 10),
                                  ),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: screenHeight * 0.025,
                                    ),
                                    SizedBox(width: screenWidth * 0.02),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: screenWidth * 0.035,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.025),
                            ],

                            Text(
                              AppLocalizations.of(context)!.editpassword_note,
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: screenWidth * 0.03,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: screenHeight * 0.02),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String error = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(_onFieldChanged);
    confirmPasswordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    newPasswordController.removeListener(_onFieldChanged);
    confirmPasswordController.removeListener(_onFieldChanged);
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool _isValidForm() {
    return newPasswordController.text.trim().isNotEmpty &&
        confirmPasswordController.text.trim().isNotEmpty &&
        newPasswordController.text.trim() ==
            confirmPasswordController.text.trim();
  }

  Future<void> submitPasswordChange() async {
    if (!_isValidForm()) {
      setState(
        () => error = AppLocalizations.of(
          context,
        )!.editpassword_add_required_correctly,
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
      if (token == null || token.isEmpty) {
        setState(
          () =>
              error = AppLocalizations.of(context)!.editpassword_error_no_token,
        );
        setState(() => loading = false);
        return;
      }
      // Only send the OTP, do not change the password yet
      final response = await http.put(
        Uri.parse('$baseUrl2/editpassword/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'password': newPasswordController.text.trim()}),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        // OTP sent, go to OTP page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerifyPassScreen(
              newPassword: newPasswordController.text.trim(),
            ),
          ),
        );
      } else {
        setState(
          () => error =
              data['error'] ??
              AppLocalizations.of(context)!.editpassword_error_sending_request,
        );
      }
    } catch (e) {
      setState(
        () =>
            error = AppLocalizations.of(context)!.editpassword_error_connecting,
      );
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return buildPasswordChangeForm(
      title: AppLocalizations.of(context)!.editpassword_title,
      controllers: {
        'newPassword': newPasswordController,
        'confirmPassword': confirmPasswordController,
      },
      onSubmit: submitPasswordChange,
      error: error,
      loading: loading,
      isFormValid: _isValidForm(),
    );
  }
}
