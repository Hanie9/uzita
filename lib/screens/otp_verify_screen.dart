import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/home_screen.dart';
import 'package:uzita/main.dart';

class OTPVerifyScreen extends StatefulWidget {
  final String phone, username, password;
  final bool isAdmin;

  const OTPVerifyScreen({
    super.key,
    required this.phone,
    required this.username,
    required this.password,
    required this.isAdmin,
  });

  @override
  State<OTPVerifyScreen> createState() => _OTPVerifyScreenState();
}

class _OTPVerifyScreenState extends State<OTPVerifyScreen> {
  final otpController = TextEditingController();
  int secondsLeft = 120;
  Timer? _timer;
  String error = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          if (secondsLeft > 0) {
            secondsLeft--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> verifyOtp() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      // مرحله اول: تایید OTP
      final endpoint = widget.isAdmin
          ? '/register/verify_admin/'
          : '/register/verify/';
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone, 'otp': otpController.text}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // مرحله دوم: لاگین
        final loginResponse = await http.post(
          Uri.parse('$baseUrl/login/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': widget.username,
            'password': widget.password,
          }),
        );

        final loginData = json.decode(loginResponse.body);

        if (loginResponse.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', loginData['token']);

          // مستقیماً به صفحه خانه برو (بدون لود کردن دیتا)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        } else {
          setState(() {
            error =
                loginData['detail'] ??
                AppLocalizations.of(
                  context,
                )!.otpverify_error_unsuccessful_login;
          });
        }
      } else {
        setState(() {
          error =
              data['error'] ??
              AppLocalizations.of(context)!.otpverify_error_not_correct;
        });
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context)!.otpverify_error_connecting;
      });
      print('خطا در تایید OTP: $e');
    }

    setState(() => loading = false);
  }

  Future<void> resendOTP() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final endpoint = widget.isAdmin
          ? '/register/resend_admin/'
          : '/register/resend/';
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': widget.phone}),
      );

      if (response.statusCode == 200) {
        setState(() {
          secondsLeft = 120;
          otpController.clear();
        });

        _timer?.cancel();
        _timer = Timer.periodic(Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() {
              if (secondsLeft > 0) {
                secondsLeft--;
              } else {
                _timer?.cancel();
              }
            });
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.otpverify_send_new_code,
            ),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        final data = json.decode(response.body);
        setState(() {
          error =
              data['error'] ??
              AppLocalizations.of(context)!.otpverify_error_sending_again;
        });
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context)!.otpverify_error_connecting;
      });
    }

    setState(() => loading = false);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.otpverify_submit_code,
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Image.asset('assets/logouzita.png', height: 32),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 30),
            Icon(Icons.sms, size: 60, color: Color(0xFF007BA7)),
            SizedBox(height: 20),
            Text(
              "${AppLocalizations.of(context)!.otpverify_send_code_content_1} ${widget.phone} ${AppLocalizations.of(context)!.otpverify_send_code_content_2}",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.otpverify_otp_code,
                hintText: '------',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
              onSubmitted: (_) => loading ? null : verifyOtp(),
            ),
            SizedBox(height: 20),
            if (secondsLeft > 0)
              Text(
                "${AppLocalizations.of(context)!.otpverify_remaining_time} ${_formatTime(secondsLeft)}",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF007BA7),
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              TextButton(
                onPressed: loading ? null : resendOTP,
                child: Text(
                  AppLocalizations.of(context)!.otpverify_resend_code,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading || otpController.text.length < 4
                  ? null
                  : verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                minimumSize: Size(double.infinity, 50),
              ),
              child: loading
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Text(
                      AppLocalizations.of(context)!.otpverify_submit,
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            if (error.isNotEmpty) ...[
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
