import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/otp_verify_screen.dart';
import 'package:uzita/utils/build_register_form.dart';

class UserRegisterScreen extends StatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  State<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends State<UserRegisterScreen> {
  final phoneController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final organCodeController = TextEditingController();

  String error = '';
  String phoneError = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_onFieldChanged);
    usernameController.addListener(_onFieldChanged);
    passwordController.addListener(_onFieldChanged);
    organCodeController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    phoneController.removeListener(_onFieldChanged);
    usernameController.removeListener(_onFieldChanged);
    passwordController.removeListener(_onFieldChanged);
    organCodeController.removeListener(_onFieldChanged);
    phoneController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    organCodeController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // بررسی تغییرات شماره تلفن
    String phoneText = phoneController.text;

    // حذف صفر اول به صورت خودکار
    if (phoneText.startsWith('0') && phoneText.length > 1) {
      phoneText = phoneText.substring(1);
      phoneController.value = TextEditingValue(
        text: phoneText,
        selection: TextSelection.collapsed(offset: phoneText.length),
      );
    }

    // محدود کردن به 10 رقم
    if (phoneText.length > 10) {
      phoneText = phoneText.substring(0, 10);
      phoneController.value = TextEditingValue(
        text: phoneText,
        selection: TextSelection.collapsed(offset: phoneText.length),
      );
    }

    // به‌روزرسانی state برای validation فرم
    setState(() {
      if (phoneText.isNotEmpty && phoneText.length < 10) {
        phoneError = AppLocalizations.of(context)!.userreg_add_phone_completely;
      } else {
        phoneError = '';
      }
    });
  }

  bool _isValidForm() {
    return phoneController.text.length == 10 &&
        usernameController.text.trim().isNotEmpty &&
        passwordController.text.trim().isNotEmpty &&
        organCodeController.text.trim().isNotEmpty;
  }

  String _translateError(String error) {
    Map<String, String> errorTranslations = {
      'نام کاربری قبلاً استفاده شده است.': AppLocalizations.of(
        context,
      )!.userreg_add_username_exist,
      'شماره تماس قبلاً استفاده شده است.': AppLocalizations.of(
        context,
      )!.userreg_add_phone_exist,
      'کد سازمان وجود ندارد.': AppLocalizations.of(
        context,
      )!.userreg_add_organ_code_exist,
      'همه فیلدها الزامی هستند.': AppLocalizations.of(
        context,
      )!.userreg_add_required,
      'خطا در ارسال پیامک.': AppLocalizations.of(context)!.userreg_add_error,
    };

    return errorTranslations[error] ?? error;
  }

  Future<void> sendOtp() async {
    if (!_isValidForm()) {
      setState(
        () => error = AppLocalizations.of(
          context,
        )!.userreg_add_required_correctly,
      );
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/start/'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode({
          'phone': phoneController.text.trim(),
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
          'organ_code': organCodeController.text.trim(),
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerifyScreen(
              phone: phoneController.text.trim(),
              username: usernameController.text.trim(),
              password: passwordController.text.trim(),
              isAdmin: false,
            ),
          ),
        );
      } else {
        setState(
          () => error = _translateError(data['error'] ?? 'خطا در ارسال کد'),
        );
      }
    } catch (e) {
      setState(
        () => error = AppLocalizations.of(context)!.userreg_error_connecting,
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return buildRegisterForm(
      title: AppLocalizations.of(context)!.userreg_title,
      controllers: {
        'phone': phoneController,
        'username': usernameController,
        'password': passwordController,
        'organ_code': organCodeController,
      },
      onSubmit: sendOtp,
      error: error,
      phoneError: phoneError,
      loading: loading,
      isFormValid: _isValidForm(),
    );
  }
}
