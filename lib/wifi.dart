import 'package:flutter/material.dart';
import 'package:uzita/main.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/utils/ui_scale.dart';

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
        Uri.parse('$baseUrl/wifi'),
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
          padding: EdgeInsets.fromLTRB(
            ui.scale(base: 20, min: 12, max: 24),
            ui.scale(base: 20, min: 14, max: 28),
            ui.scale(base: 20, min: 12, max: 24),
            ui.scale(base: 20, min: 14, max: 28) +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ui.scale(base: 24, min: 16, max: 28)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lapisLazuli,
                      AppColors.lapisLazuli.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    ui.scale(base: 16, min: 12, max: 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                      blurRadius: ui.scale(base: 10, min: 8, max: 14),
                      offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ui.scale(base: 16, min: 12, max: 20),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi,
                        size: ui.scale(base: 40, min: 28, max: 48),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                    Text(
                      AppLocalizations.of(context)!.wifi_header,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ui.scale(base: 20, min: 16, max: 24),
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
                    Text(
                      AppLocalizations.of(context)!.wifi_subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: ui.scale(base: 14, min: 12, max: 16),
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ],
                ),
              ),

              SizedBox(height: ui.scale(base: 24, min: 16, max: 28)),

              // Instructions Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 20, min: 14, max: 24),
                  ui.scale(base: 20, min: 14, max: 24),
                  ui.scale(base: 20, min: 14, max: 24),
                  ui.scale(base: 20, min: 14, max: 24) +
                      MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(
                    ui.scale(base: 16, min: 12, max: 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: ui.scale(base: 10, min: 8, max: 14),
                      offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
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
                            ui.scale(base: 8, min: 6, max: 12),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              ui.scale(base: 8, min: 6, max: 12),
                            ),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: AppColors.lapisLazuli,
                            size: ui.scale(base: 20, min: 16, max: 24),
                          ),
                        ),
                        SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                        Text(
                          AppLocalizations.of(context)!.wifi_steps_title,
                          style: TextStyle(
                            fontSize: ui.scale(base: 16, min: 14, max: 18),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).textTheme.titleMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                    _buildInstructionStep(
                      number: '1',
                      text: AppLocalizations.of(context)!.wifi_step_1,
                    ),
                    SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                    _buildInstructionStep(
                      number: '2',
                      text: AppLocalizations.of(context)!.wifi_step_2,
                    ),
                  ],
                ),
              ),

              SizedBox(height: ui.scale(base: 24, min: 16, max: 28)),

              // Form Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(ui.scale(base: 24, min: 16, max: 28)),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(
                    ui.scale(base: 16, min: 12, max: 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: ui.scale(base: 10, min: 8, max: 14),
                      offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.wifi_info_title,
                      style: TextStyle(
                        fontSize: ui.scale(base: 18, min: 16, max: 20),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),

                    // SSID Field
                    Text(
                      AppLocalizations.of(context)!.wifi_ssid_label,
                      style: TextStyle(
                        fontSize: ui.scale(base: 14, min: 12, max: 16),
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
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
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
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

                    SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),

                    // Password Field
                    Text(
                      AppLocalizations.of(context)!.wifi_password_label,
                      style: TextStyle(
                        fontSize: ui.scale(base: 14, min: 12, max: 16),
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
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
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
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

                    SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),

                    // Device Token Field
                    Text(
                      AppLocalizations.of(context)!.wifi_token_label,
                      style: TextStyle(
                        fontSize: ui.scale(base: 14, min: 12, max: 16),
                        fontWeight: FontWeight.w600,
                        color: AppColors.lapisLazuli,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 8, min: 6, max: 12)),
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
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            ui.scale(base: 12, min: 10, max: 16),
                          ),
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

                    SizedBox(height: ui.scale(base: 24, min: 16, max: 28)),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: ui.scale(base: 56, min: 44, max: 64),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : sendWifiCredentials,
                        icon: _isLoading
                            ? SizedBox(
                                width: ui.scale(base: 24, min: 18, max: 28),
                                height: ui.scale(base: 24, min: 18, max: 28),
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
                          _isLoading
                              ? AppLocalizations.of(
                                  context,
                                )!.wifi_sending_button
                              : AppLocalizations.of(context)!.wifi_send_button,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui.scale(base: 16, min: 14, max: 18),
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapisLazuli,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ui.scale(base: 12, min: 10, max: 16),
                            ),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: ui.scale(base: 20, min: 14, max: 24)),

              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(ui.scale(base: 16, min: 12, max: 20)),
                  decoration: BoxDecoration(
                    color: _statusMessage.contains('✅')
                        ? AppColors.lapisLazuli.withValues(alpha: 0.1)
                        : _statusMessage.contains('❌')
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.bronzeGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      ui.scale(base: 12, min: 10, max: 16),
                    ),
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
                        size: ui.scale(base: 20, min: 16, max: 24),
                      ),
                      SizedBox(width: ui.scale(base: 12, min: 8, max: 16)),
                      Expanded(
                        child: Text(
                          _statusMessage
                              .replaceAll('✅', '')
                              .replaceAll('❌', ''),
                          style: TextStyle(
                            fontSize: ui.scale(base: 14, min: 12, max: 16),
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
