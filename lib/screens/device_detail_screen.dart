import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Map device;
  const DeviceDetailScreen(this.device, {super.key});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int selectedCode = 1;
  bool loading = false;
  String? message;
  bool isSuccess = false;
  late bool isActive;
  int userLevel = 3; // Default to level 3

  @override
  void initState() {
    super.initState();
    isActive = widget.device['active'] ?? true;
    _loadUserLevel();
  }

  Future<void> _loadUserLevel() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userLevel = prefs.getInt('level') ?? 3;
    });
  }

  Future<void> sendCommand() async {
    setState(() {
      loading = true;
      message = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      await SessionManager().onNetworkRequest();
      final response = await http.post(
        Uri.parse('$baseUrl/sendcommand/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'serial_number': widget.device['serial_number'],
          'code': selectedCode,
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      setState(() {
        isSuccess = response.statusCode == 201;
        message =
            data['success'] ??
            data['error'] ??
            AppLocalizations.of(context)!.dds_error_command;
      });
    } catch (e) {
      setState(() {
        isSuccess = false;
        message = AppLocalizations.of(context)!.dds_error_connecting;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> toggleActivation() async {
    final confirm = await showConfirmationDialog(
      context,
      title: isActive
          ? AppLocalizations.of(context)!.dds_deactivate_device
          : AppLocalizations.of(context)!.dds_activate_device,
      message: AppLocalizations.of(context)!.dds_are_you_sure,
    );
    if (!confirm) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    await SessionManager().onNetworkRequest();
    final response = await http.post(
      Uri.parse('$baseUrl/activatedevice/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': widget.device['name']}),
    );

    final data = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      setState(() {
        isActive = !isActive;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['massage']), backgroundColor: Colors.teal),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['error'] ??
                AppLocalizations.of(context)!.dds_error_changing_status,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteDevice() async {
    final confirm = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context)!.dds_delete_device,
      message: AppLocalizations.of(context)!.dds_delete_device_description,
    );
    if (!confirm) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    await SessionManager().onNetworkRequest();
    final response = await http.post(
      Uri.parse('$baseUrl/deletedevice/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': widget.device['name']}),
    );

    final data = json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.dds_delete_device_success,
          ),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context); // برگرد به صفحه لیست
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['error'] ??
                AppLocalizations.of(context)!.dds_delete_device_error,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDeviceInfoCard() {
    final deviceName =
        (widget.device['name'] ?? AppLocalizations.of(context)!.dds_unknown)
            .toString();
    final serialNumber = (widget.device['serial_number'] ?? '---').toString();
    final status =
        (widget.device['status'] ?? AppLocalizations.of(context)!.dds_unknown)
            .toString();
    final statusColor = isActive ? Color(0xFF00A86B) : Colors.red;
    final statusText = isActive
        ? AppLocalizations.of(context)!.dds_active
        : AppLocalizations.of(context)!.dds_inactive;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with device icon and status
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.lapisLazuli.withValues(alpha: 0.15)
                  : AppColors.lapisLazuli.withValues(alpha: 0.08),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              textDirection: Directionality.of(context),
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.lapisLazuli.withValues(alpha: 0.25)
                        : AppColors.lapisLazuli.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.devices_other,
                    color: AppColors.lapisLazuli,
                    size: 32,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        deviceName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: Directionality.of(context),
                        textAlign: TextAlign.right,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              textDirection: Directionality.of(context),
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.cancel,
                                  size: 16,
                                  color: statusColor,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textDirection: Directionality.of(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 0,
            thickness: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]
                : Colors.grey[200],
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: Directionality.of(context),
                  children: [
                    Icon(
                      Icons.numbers,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.dds_serial_number,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        serialNumber,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: Directionality.of(context),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  textDirection: Directionality.of(context),
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.dds_status,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: Directionality.of(context),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with icon and title
          Row(
            textDirection: Directionality.of(context),
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.lapisLazuli.withValues(alpha: 0.25)
                      : AppColors.lapisLazuli.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.send, color: AppColors.lapisLazuli, size: 24),
              ),
              SizedBox(width: 16),
              Text(
                AppLocalizations.of(context)!.dds_send_command,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Command dropdown
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[600]!
                    : Colors.grey[300]!,
              ),
            ),
            child: DropdownButtonFormField<int>(
              value: selectedCode,
              onChanged: (val) => setState(() => selectedCode = val!),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                labelText: AppLocalizations.of(context)!.dds_choose_command,
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                prefixIcon: Icon(Icons.settings, color: AppColors.lapisLazuli),
              ),
              items: List.generate(20, (i) => i + 1)
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        '${AppLocalizations.of(context)!.dds_command} $e',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          SizedBox(height: 24),

          // Send command button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: loading ? null : sendCommand,
              icon: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.send),
              label: Text(
                loading
                    ? AppLocalizations.of(context)!.dds_sending
                    : AppLocalizations.of(context)!.dds_send_command,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapisLazuli,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.lapisLazuli.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        children: [
          // Hide disable and delete buttons for level 3 users
          if (userLevel < 3) ...[
            // Activation toggle button
            Container(
              width: double.infinity,
              height: 56,
              margin: EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: toggleActivation,
                icon: Icon(isActive ? Icons.block : Icons.check_circle),
                label: Text(
                  isActive
                      ? AppLocalizations.of(context)!.dds_deactivate_device
                      : AppLocalizations.of(context)!.dds_activate_device,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? Colors.orange[600]
                      : AppColors.lapisLazuli,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor:
                      (isActive ? Colors.orange[600] : AppColors.lapisLazuli)!
                          .withValues(alpha: 0.3),
                ),
              ),
            ),

            // Delete button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: deleteDevice,
                icon: Icon(Icons.delete_forever),
                label: Text(
                  AppLocalizations.of(context)!.dds_delete_device,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: Colors.red.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    if (message == null) return SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        textDirection: Directionality.of(context),
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              message!,
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              textDirection: Directionality.of(context),
            ),
          ),
        ],
      ),
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
                        AppLocalizations.of(context)!.dds_details_device,
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
        textDirection: Localizations.localeOf(context).languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            12,
            16,
            12,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDeviceInfoCard(),
              SizedBox(height: 16),
              _buildCommandCard(),
              SizedBox(height: 16),
              _buildMessageCard(),
              SizedBox(height: 16),
              _buildActionButtons(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: Localizations.localeOf(ctx).languageCode == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: AppColors.lapisLazuli,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontFamily: 'Vazir',
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        AppLocalizations.of(context)!.dds_no,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontFamily: 'Vazir',
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapisLazuli,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        AppLocalizations.of(context)!.dds_yes,
                        style: TextStyle(fontFamily: 'Vazir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
  }
}
