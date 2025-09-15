import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/screens/device_detail_screen.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/ui_scale.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List devices = [];
  int selectedNavIndex = 1; // Devices tab is active
  bool isLoading = true;
  String username = '';
  int userLevel = 3;
  String userRoleTitle = '';
  bool userModir = false;
  bool userActive = false;
  DateTime? _lastBackPressedAt;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _openAddDeviceDialog() async {
    final nameController = TextEditingController();
    final serialController = TextEditingController();
    bool submitting = false;
    String? returnedToken;
    String? serverMessage;
    String? copyInlineMessage;

    String? localError;
    bool nameError = false;
    bool serialError = false;

    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final name = nameController.text.trim();
            final serial = serialController.text.trim();
            if (name.isEmpty || serial.isEmpty) {
              setDialogState(() {
                nameError = name.isEmpty;
                serialError = serial.isEmpty;
                localError = AppLocalizations.of(context)!.dls_local_error;
              });
              return;
            }
            setDialogState(() => submitting = true);
            try {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              // final ts = DateTime.now().millisecondsSinceEpoch; // not used

              // Match other requests pattern: JSON body with content-type
              await SessionManager().onNetworkRequest();
              final resp = await http.post(
                Uri.parse('$baseUrl/adddevice/'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode({'name': name, 'serial_number': serial}),
              );

              final body = utf8.decode(resp.bodyBytes);
              dynamic data;
              try {
                data = json.decode(body);
              } catch (_) {
                data = {};
              }

              if (resp.statusCode == 200 || resp.statusCode == 201) {
                returnedToken = (data is Map)
                    ? (data['token'] ?? data['device_token'] ?? data['key'])
                    : null;
                serverMessage = (data is Map)
                    ? (data['message'] ??
                          data['massage'] ??
                          AppLocalizations.of(context)!.dls_device_added)
                    : AppLocalizations.of(context)!.dls_device_added;
                setDialogState(() {});
                await fetchDevices();
              } else {
                final errText = (data is Map)
                    ? (data['error'] ?? data['detail'] ?? body).toString()
                    : body;
                setDialogState(() {
                  localError =
                      '${AppLocalizations.of(context)!.dls_error}: $errText';
                });
              }
            } catch (e) {
              setDialogState(() {
                localError = AppLocalizations.of(context)!.dls_error_connecting;
              });
            } finally {
              setDialogState(() => submitting = false);
            }
          }

          return AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            scrollable: true,
            title: Row(
              children: [
                Icon(Icons.add_box, color: AppColors.lapisLazuli),
                SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.dls_add_device),
              ],
            ),
            content: returnedToken == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        textDirection: Directionality.of(context),
                        textAlign:
                            Directionality.of(context) == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.dls_name_device,
                          prefixIcon: Icon(Icons.devices_other),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: nameError
                              ? AppLocalizations.of(context)!.dls_name_error
                              : null,
                        ),
                        onChanged: (_) => setDialogState(() {
                          nameError = false;
                          localError = null;
                        }),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: serialController,
                        textDirection: Directionality.of(context),
                        textAlign:
                            Directionality.of(context) == TextDirection.rtl
                            ? TextAlign.right
                            : TextAlign.left,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          )!.dls_serial_number,
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: serialError
                              ? AppLocalizations.of(
                                  context,
                                )!.dls_serial_number_error
                              : null,
                          suffixIcon: IconButton(
                            tooltip: AppLocalizations.of(context)!.dls_scan,
                            icon: Icon(Icons.qr_code_scanner),
                            onPressed: () async {
                              try {
                                var permissionStatus =
                                    await Permission.camera.status;
                                if (!permissionStatus.isGranted) {
                                  permissionStatus = await Permission.camera
                                      .request();
                                }
                                if (!permissionStatus.isGranted) {
                                  setDialogState(() {
                                    localError = AppLocalizations.of(
                                      context,
                                    )!.dls_camera_permission_denied;
                                  });
                                  if (permissionStatus.isPermanentlyDenied) {
                                    await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.dls_camera_permission_denied,
                                        ),
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.dls_camera_permission_denied_description,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.login_cancle,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(ctx).pop();
                                              openAppSettings();
                                            },
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.dls_settings,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final scanned = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const _SerialScannerPage(),
                                  ),
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  serialController.text = scanned.trim();
                                  setDialogState(() {
                                    serialError = false;
                                    localError = null;
                                  });
                                }
                              } catch (_) {}
                            },
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {
                          serialError = false;
                          localError = null;
                        }),
                      ),
                      if (localError != null) ...[
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localError!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                                textDirection: Directionality.of(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (serverMessage != null) ...[
                        Text(
                          serverMessage!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context)!.dls_token),
                          IconButton(
                            tooltip: AppLocalizations.of(context)!.dls_copy,
                            onPressed:
                                (returnedToken == null ||
                                    returnedToken!.isEmpty)
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: returnedToken!),
                                    );
                                    setDialogState(() {
                                      copyInlineMessage = AppLocalizations.of(
                                        context,
                                      )!.dls_copy_success;
                                    });
                                  },
                            icon: Icon(
                              Icons.copy,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          returnedToken ?? '-',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context)!.dls_note_token),
                          SizedBox(height: 8),
                          if (copyInlineMessage != null)
                            Text(
                              copyInlineMessage!,
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: submitting
                          ? null
                          : () => Navigator.of(dialogCtx).pop(),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          returnedToken == null
                              ? AppLocalizations.of(context)!.dls_cancel
                              : AppLocalizations.of(context)!.dls_close,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                  if (returnedToken == null) ...[
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: submitting ? null : submit,
                        icon: submitting
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(Icons.save, color: Colors.white),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            submitting
                                ? AppLocalizations.of(context)!.dls_submitting
                                : AppLocalizations.of(context)!.dls_submit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapisLazuli,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size(0, 44),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> fetchDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final ts = DateTime.now().millisecondsSinceEpoch;
      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl/listdevice/?ts=$ts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);
        if (data is Map && data['error'] != null) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data['error'].toString())));
          return;
        }

        List<dynamic> allDevices = (data as List);

        setState(() {
          devices = allDevices;
          isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.dls_no_access)),
        );
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.dls_error_fetching_devices} (${response.statusCode})',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.dls_error_connecting),
        ),
      );
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final name = device['name'] ?? AppLocalizations.of(context)!.dls_unknown;
    final serial = device['serial_number'] ?? '---';
    final status =
        device['status'] ?? AppLocalizations.of(context)!.dls_unknown;

    // Determine status color
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status.toString().toLowerCase()) {
      case 'active':
      case 'فعال':
        statusColor = Color(0xFF00A86B);
        statusIcon = Icons.check_circle;
        statusText = AppLocalizations.of(context)!.dls_active;
        break;
      case 'inactive':
      case 'غیرفعال':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = AppLocalizations.of(context)!.dls_inactive;
        break;
      case 'maintenance':
      case 'تعمیر':
        statusColor = Color(0xFFD4AF37);
        statusIcon = Icons.build;
        statusText = AppLocalizations.of(context)!.dls_maintenance;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status.toString();
    }

    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DeviceDetailScreen(device)),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              UiScale(context).scale(base: 20, min: 12, max: 22),
            ),
            child: Row(
              children: [
                // Device Avatar
                Container(
                  width: UiScale(context).scale(base: 60, min: 48, max: 68),
                  height: UiScale(context).scale(base: 60, min: 48, max: 68),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF007BA7), Color(0xFF006990)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF007BA7).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.devices_other,
                      color: Colors.white,
                      size: UiScale(context).scale(base: 28, min: 22, max: 30),
                    ),
                  ),
                ),
                SizedBox(
                  width: UiScale(context).scale(base: 16, min: 10, max: 18),
                ),

                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.numbers,
                            color: theme.iconTheme.color?.withValues(
                              alpha: 0.7,
                            ),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '${AppLocalizations.of(context)!.dls_serial_number}:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            serial,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: theme.iconTheme.color?.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.grey[850]!, Colors.grey[800]!]
                    : [Colors.grey[100]!, Colors.grey[200]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.devices_other,
              size: 60,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.dls_no_devices,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.dls_no_devices_description,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.lapisLazuli, AppColors.lapisLazuli],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: fetchDevices,
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text(
                AppLocalizations.of(context)!.dls_retry,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadUserData().then((_) {
      // Only fetch devices if user is active
      if (userActive) {
        fetchDevices();
      }
    });
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'کاربر';
      userLevel = prefs.getInt('level') ?? 3;
      userModir = prefs.getBool('modir') ?? false;
      userActive = prefs.getBool('active') ?? false;
      userRoleTitle = _getUserRoleTitle(userLevel, userModir);

      // If user is not active, stop loading immediately
      if (!userActive) {
        isLoading = false;
      }
    });
  }

  String _getUserRoleTitle(int level, bool modir) {
    if (level == 1 && modir) {
      return AppLocalizations.of(context)!.dls_company_representative;
    } else if (level == 1) {
      return AppLocalizations.of(context)!.dls_admin;
    }
    switch (level) {
      case 2:
        return AppLocalizations.of(context)!.dls_installer;
      case 3:
        return AppLocalizations.of(context)!.dls_regular_user;
      default:
        return AppLocalizations.of(context)!.dls_user;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If drawer is open, close it instead of exiting
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.click_again_to_exit),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: userModir
            ? FloatingActionButton.extended(
                onPressed: _openAddDeviceDialog,
                backgroundColor: AppColors.lapisLazuli,
                icon: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: UiScale(context).scale(base: 22, min: 20, max: 26),
                ),
                label: Text(
                  AppLocalizations.of(context)!.dls_add_device,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: UiScale(
                      context,
                    ).scale(base: 14, min: 12, max: 16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                extendedPadding: EdgeInsets.symmetric(
                  horizontal: UiScale(
                    context,
                  ).scale(base: 16, min: 12, max: 20),
                ),
              )
            : null,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Left side - Icons
                    Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: Icon(
                              Icons.menu,
                              color: theme.appBarTheme.iconTheme?.color,
                            ),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.notifications,
                            color: theme.appBarTheme.iconTheme?.color,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),

                    // Center - Text
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.dls_title,
                          style: theme.appBarTheme.titleTextStyle,
                        ),
                      ),
                    ),

                    // Right side - Logo and refresh button
                    Row(
                      children: [
                        Image.asset(
                          'assets/logouzita.png',
                          height: screenHeight * 0.08,
                          width: screenHeight * 0.08,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        drawer: SharedAppDrawer(
          username: username,
          userRoleTitle: userRoleTitle,
          userModir: userModir,
          userLevel: userLevel,
          refreshUserData: fetchDevices,
          logout: () async {
            final prefs = await SharedPreferences.getInstance();
            // Preserve user preferences
            final saved = prefs.getString('saved_username');
            final preservedLanguage = prefs.getString('selectedLanguage');
            final preservedDarkMode = prefs.getBool('darkModeEnabled');
            final preservedTextSize = prefs.getDouble('textSize');
            final preservedNotifications = prefs.getBool(
              'notificationsEnabled',
            );

            await prefs.clear();

            // Restore preserved settings
            if (saved != null && saved.isNotEmpty) {
              await prefs.setString('saved_username', saved);
            }
            if (preservedLanguage != null && preservedLanguage.isNotEmpty) {
              await prefs.setString('selectedLanguage', preservedLanguage);
            }
            if (preservedDarkMode != null) {
              await prefs.setBool('darkModeEnabled', preservedDarkMode);
            }
            if (preservedTextSize != null) {
              await prefs.setDouble('textSize', preservedTextSize);
            }
            if (preservedNotifications != null) {
              await prefs.setBool(
                'notificationsEnabled',
                preservedNotifications,
              );
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
          },
          userActive: userActive,
        ),
        body: userActive
            ? Column(
                children: [
                  // Header (shrink-wrapped)
                  Directionality(
                    textDirection:
                        Provider.of<SettingsProvider>(
                              context,
                              listen: false,
                            ).selectedLanguage ==
                            'en'
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header section with device count
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.lapisLazuli,
                                AppColors.lapisLazuli.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lapisLazuli.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.router,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.dls_title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        isLoading
                                            ? Row(
                                                children: [
                                                  SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '${devices.length} ${AppLocalizations.of(context)!.dls_count_suffix}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ],
                                    ),

                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.settings,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    )!.dls_manage,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Device list (takes all available space)
                  Flexible(
                    child: Directionality(
                      textDirection:
                          Provider.of<SettingsProvider>(
                                context,
                                listen: false,
                              ).selectedLanguage ==
                              'en'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      child: isLoading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.lapisLazuli.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.lapisLazuli.withValues(
                                              alpha: 0.05,
                                            ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.lapisLazuli.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.lapisLazuli,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.dls_loading_devices,
                                    style: TextStyle(
                                      color: AppColors.lapisLazuli,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.dls_please_wait,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : devices.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: fetchDevices,
                              color: Color(0xFF00A86B),
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                itemCount: devices.length,
                                itemBuilder: (context, index) {
                                  return _buildDeviceCard(devices[index]);
                                },
                              ),
                            ),
                    ),
                  ),
                  // Moved bottom navigation to Scaffold.bottomNavigationBar
                ],
              )
            : _buildInactiveState(),
        bottomNavigationBar: SharedBottomNavigation(
          selectedIndex: selectedNavIndex,
          userLevel: userLevel,
          onItemTapped: _onNavItemTapped,
        ),
      ),
    );
  }

  // Inactive state for level 3 users
  Widget _buildInactiveState() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.lapisLazuli.withValues(alpha: 0.2)
                    : AppColors.lapisLazuli.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.devices_outlined,
                size: 64,
                color: AppColors.lapisLazuli,
              ),
            ),

            SizedBox(height: 24),

            // Title
            Text(
              AppLocalizations.of(context)!.dls_devices_awaiting_activation,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),

            SizedBox(height: 12),

            // Description
            Text(
              AppLocalizations.of(
                context,
              )!.dls_devices_awaiting_activation_description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),

            SizedBox(height: 32),

            // Contact Admin Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.dls_contact_admin,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.lapisLazuli,
                    ),
                  );
                },
                icon: Icon(Icons.support_agent, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.dls_contact_admin_button,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lapisLazuli,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.lapisLazuli.withValues(alpha: 0.8)
                        : AppColors.lapisLazuli,
                    width: 2,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      selectedNavIndex = index;
    });

    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1: // Devices - already here
        break;
      case 2: // Reports
        Navigator.pushReplacementNamed(context, '/commands');
        break;
      case 3: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case 4: // Users
        Navigator.pushReplacementNamed(context, '/users');
        break;
    }
  }

  // Removed old WillPopScope handler; PopScope handles back now
}

class _SerialScannerPage extends StatefulWidget {
  const _SerialScannerPage();
  @override
  State<_SerialScannerPage> createState() => _SerialScannerPageState();
}

class _SerialScannerPageState extends State<_SerialScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: true,
    facing: CameraFacing.back,
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
    ],
  );
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Ensure scanner is started
    _controller.start().catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dls_scan_barcode),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.dls_on_and_off_flash,
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.dls_switch_camera,
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (_handled) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final raw = (barcodes.first.rawValue ?? '').trim();
                  if (raw.isNotEmpty) {
                    _handled = true;
                    Navigator.of(context).pop(raw);
                  }
                }
              },
            ),
          ),
          // Overlay mask with cut-out viewfinder
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  borderColor: AppColors.lapisLazuli,
                  overlayColor: theme.colorScheme.surface.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ),
          // Bottom action bar
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.dls_scan_hint,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      )!.dls_scan_from_gallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _pickFromGallery,
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.dls_scan_from_file,
                      icon: const Icon(Icons.attach_file),
                      onPressed: _pickFromFiles,
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.dls_close_scan,
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final result = await _controller.analyzeImage(picked.path);
      final bytes = await picked.readAsBytes();
      String? raw;
      if (result != null && result.barcodes.isNotEmpty) {
        raw = (result.barcodes.first.rawValue ?? '').trim();
      }
      await _showImageResult(bytes, raw?.isNotEmpty == true ? raw : null);
    } catch (_) {}
  }

  Future<void> _pickFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final path = res?.files.single.path;
      if (path == null) return;
      final result = await _controller.analyzeImage(path);
      Uint8List? bytes = res!.files.single.bytes;
      bytes ??= await File(res.files.single.path!).readAsBytes();
      String? raw;
      if (result != null && result.barcodes.isNotEmpty) {
        raw = (result.barcodes.first.rawValue ?? '').trim();
      }
      await _showImageResult(bytes, raw?.isNotEmpty == true ? raw : null);
    } catch (_) {}
  }

  Future<void> _showImageResult(Uint8List imageBytes, String? code) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    height: MediaQuery.of(ctx).size.height * 0.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  code == null
                      ? AppLocalizations.of(context)!.dls_no_barcode_found
                      : '${AppLocalizations.of(context)!.dls_barcode_found}: $code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: code == null ? Colors.red : AppColors.lapisLazuli,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          AppLocalizations.of(context)!.dls_close_scan,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: code == null
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                _handled = true;
                                Navigator.of(context).pop(code);
                              },
                        child: Text(AppLocalizations.of(context)!.dls_use_code),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  _ScannerOverlayPainter({
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final rect = Offset.zero & size;
    // Viewfinder rect (centered square)
    final double width = size.width * 0.75;
    final double height = width;
    final Rect hole = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: height,
    );

    // Overlay with hole
    final overlayPath = Path()..addRect(rect);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlayPath, holePath),
      paint,
    );

    // Draw border corners
    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const double cornerLen = 28;
    const double radius = 16;

    // Top-left
    _drawCorner(
      canvas,
      hole.topLeft,
      cornerLen,
      CornerPosition.topLeft,
      cornerPaint,
      radius,
    );
    // Top-right
    _drawCorner(
      canvas,
      hole.topRight,
      cornerLen,
      CornerPosition.topRight,
      cornerPaint,
      radius,
    );
    // Bottom-left
    _drawCorner(
      canvas,
      hole.bottomLeft,
      cornerLen,
      CornerPosition.bottomLeft,
      cornerPaint,
      radius,
    );
    // Bottom-right
    _drawCorner(
      canvas,
      hole.bottomRight,
      cornerLen,
      CornerPosition.bottomRight,
      cornerPaint,
      radius,
    );
  }

  void _drawCorner(
    Canvas canvas,
    Offset corner,
    double len,
    CornerPosition pos,
    Paint paint,
    double radius,
  ) {
    final path = Path();
    switch (pos) {
      case CornerPosition.topLeft:
        path.moveTo(corner.dx, corner.dy + radius);
        path.lineTo(corner.dx, corner.dy + len);
        path.moveTo(corner.dx + radius, corner.dy);
        path.lineTo(corner.dx + len, corner.dy);
        break;
      case CornerPosition.topRight:
        path.moveTo(corner.dx, corner.dy + radius);
        path.lineTo(corner.dx, corner.dy + len);
        path.moveTo(corner.dx - radius, corner.dy);
        path.lineTo(corner.dx - len, corner.dy);
        break;
      case CornerPosition.bottomLeft:
        path.moveTo(corner.dx, corner.dy - radius);
        path.lineTo(corner.dx, corner.dy - len);
        path.moveTo(corner.dx + radius, corner.dy);
        path.lineTo(corner.dx + len, corner.dy);
        break;
      case CornerPosition.bottomRight:
        path.moveTo(corner.dx, corner.dy - radius);
        path.lineTo(corner.dx, corner.dy - len);
        path.moveTo(corner.dx - radius, corner.dy);
        path.lineTo(corner.dx - len, corner.dy);
        break;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.overlayColor != overlayColor ||
        oldDelegate.borderColor != borderColor;
  }
}

enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }
