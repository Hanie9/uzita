import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';

const String baseUrl2 = 'https://uzita-iot.ir/api';

class OTPVerifyPassScreen extends StatefulWidget {
  final String newPassword;

  const OTPVerifyPassScreen({super.key, required this.newPassword});

  @override
  State<OTPVerifyPassScreen> createState() => _OTPVerifyPassScreenState();
}

class _OTPVerifyPassScreenState extends State<OTPVerifyPassScreen> {
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.post(
        Uri.parse('$baseUrl2/editpassword/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'otp': otpController.text.trim(),
          'password': widget.newPassword,
        }),
      );
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            title: Text(
              AppLocalizations.of(context)!.otpverifypass_success_title,
            ),
            content: Text(
              AppLocalizations.of(context)!.otpverifypass_success_content,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  AppLocalizations.of(context)!.otpverifypass_success_button,
                ),
              ),
            ],
          ),
        );
      } else {
        setState(
          () => error =
              data['error'] ??
              AppLocalizations.of(context)!.otpverifypass_error_not_correct,
        );
      }
    } catch (e) {
      setState(
        () => error = AppLocalizations.of(
          context,
        )!.otpverifypass_error_connecting,
      );
    }
    setState(() => loading = false);
  }

  Future<void> resendOTP() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.post(
        Uri.parse('$baseUrl2/editpassword/resend_otp/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
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
              AppLocalizations.of(context)!.otpverifypass_send_new_code,
            ),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        final data = json.decode(response.body);
        setState(() {
          error =
              data['error'] ??
              AppLocalizations.of(context)!.otpverifypass_error_sending_again;
        });
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context)!.otpverifypass_error_connecting;
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
          AppLocalizations.of(context)!.otpverifypass_submit_code,
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
              AppLocalizations.of(context)!.otpverifypass_type_code,
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
                labelText: AppLocalizations.of(context)!.otpverifypass_otp_code,
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
                "${AppLocalizations.of(context)!.otpverifypass_remaining_time} ${_formatTime(secondsLeft)}",
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
                  AppLocalizations.of(context)!.otpverifypass_resend_code,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading || otpController.text.length != 6
                  ? null
                  : verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007BA7),
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
                      AppLocalizations.of(context)!.otpverifypass_submit,
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
