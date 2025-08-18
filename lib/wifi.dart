import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';

class WifiConfigPage extends StatefulWidget {
  const WifiConfigPage({super.key});

  @override
  State<WifiConfigPage> createState() => _WifiConfigPageState();
}

class _WifiConfigPageState extends State<WifiConfigPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceTokenController = TextEditingController();
  String _statusMessage = '';
  bool _isLoading = false;

  Future<void> sendWifiCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    final deviceToken = _deviceTokenController.text.trim();

    if (ssid.isEmpty || password.isEmpty || deviceToken.isEmpty) {
      setState(() {
        _statusMessage = AppLocalizations.of(context)!.wifi_enter_all_fields;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = AppLocalizations.of(context)!.wifi_sending;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.4.1/wifi'),
        body: {'ssid': ssid, 'password': password, 'token': deviceToken},
      );

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage =
              '✅ ${AppLocalizations.of(context)!.wifi_send_success}';
        });
      } else {
        setState(() {
          _statusMessage =
              '❌ ${AppLocalizations.of(context)!.wifi_send_failed} ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage =
            '❌ ${AppLocalizations.of(context)!.wifi_error_connect_prefix} $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _deviceTokenController.dispose();
    super.dispose();
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
                        AppLocalizations.of(context)!.wifi_title,
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lapisLazuli,
                      AppColors.lapisLazuli.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi, size: 40, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.wifi_header,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.wifi_subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Instructions Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: AppColors.lapisLazuli,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.wifi_steps_title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).textTheme.titleMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildInstructionStep(
                      number: '1',
                      text: AppLocalizations.of(context)!.wifi_step_1,
                    ),
                    SizedBox(height: 12),
                    _buildInstructionStep(
                      number: '2',
                      text: AppLocalizations.of(context)!.wifi_step_2,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Form Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.wifi_info_title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: 20),

                    // SSID Field
                    Text(
                      AppLocalizations.of(context)!.wifi_ssid_label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _ssidController,
                      textDirection: Directionality.of(context),
                      textAlign: Directionality.of(context) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.wifi_ssid_hint,
                        filled: true,
                        fillColor: AppColors.lapisLazuli.withValues(
                          alpha: 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.lapisLazuli,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.wifi,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Password Field
                    Text(
                      AppLocalizations.of(context)!.wifi_password_label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      textDirection: Directionality.of(context),
                      textAlign: Directionality.of(context) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.wifi_password_hint,
                        filled: true,
                        fillColor: AppColors.lapisLazuli.withValues(
                          alpha: 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.lapisLazuli,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.lock,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Device Token Field
                    Text(
                      AppLocalizations.of(context)!.wifi_token_label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _deviceTokenController,
                      textDirection: Directionality.of(context),
                      textAlign: Directionality.of(context) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.wifi_token_hint,
                        filled: true,
                        fillColor: AppColors.lapisLazuli.withValues(
                          alpha: 0.04,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.lapisLazuli,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.vpn_key,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : sendWifiCredentials,
                        icon: _isLoading
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
                          _isLoading
                              ? AppLocalizations.of(
                                  context,
                                )!.wifi_sending_button
                              : AppLocalizations.of(context)!.wifi_send_button,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapisLazuli,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusMessage.contains('✅')
                        ? AppColors.lapisLazuli.withValues(alpha: 0.1)
                        : _statusMessage.contains('❌')
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.bronzeGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusMessage.contains('✅')
                          ? AppColors.lapisLazuli.withValues(alpha: 0.3)
                          : _statusMessage.contains('❌')
                          ? Colors.red.withValues(alpha: 0.3)
                          : AppColors.bronzeGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('✅')
                            ? Icons.check_circle
                            : _statusMessage.contains('❌')
                            ? Icons.error
                            : Icons.info,
                        color: _statusMessage.contains('✅')
                            ? AppColors.lapisLazuli
                            : _statusMessage.contains('❌')
                            ? Colors.red
                            : AppColors.bronzeGold,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage
                              .replaceAll('✅', '')
                              .replaceAll('❌', ''),
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.lapisLazuli,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.4,
            ),
            textDirection: Directionality.of(context),
          ),
        ),
      ],
    );
  }
}
