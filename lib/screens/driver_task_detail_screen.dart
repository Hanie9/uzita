import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/driver_route_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/driver_routing_service.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/address_geocode_hints.dart';
import 'package:uzita/utils/neshan_errors.dart';
import 'package:uzita/utils/number_format_utils.dart';
import 'package:uzita/utils/read_local_file_bytes.dart';
import 'package:uzita/utils/transport_attachment_utils.dart';
import 'package:uzita/utils/user_error_message.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/widgets/tappable_phone.dart';

class _CompleteTaskFormResult {
  const _CompleteTaskFormResult({
    required this.report,
    this.fee,
    this.receipt,
  });

  final String report;
  final int? fee;
  final PickedTransportAttachment? receipt;
}

class DriverTaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final bool isReport; // true if this is a report, false if it's a mission

  const DriverTaskDetailScreen({
    super.key,
    required this.task,
    this.isReport = false,
  });

  @override
  State<DriverTaskDetailScreen> createState() => _DriverTaskDetailScreenState();
}

class _DriverTaskDetailScreenState extends State<DriverTaskDetailScreen> {
  bool isLoading = false;
  bool isRouting = false;
  bool isDownloadingAttachment = false;
  bool isDownloadingFinalAttachment = false;
  late Map<String, dynamic> taskData;

  @override
  void initState() {
    super.initState();
    taskData = Map<String, dynamic>.from(widget.task);
  }

  /// Cargo assignment id (واگذاری بار) for live location reporting.
  int? get _assignmentId {
    final raw = taskData['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String getpaymentLabel(String value) {
    final localizations = AppLocalizations.of(context)!;

    switch (value) {
      case 'direct':
        return localizations.trn_direct;
      case 'invoice':
        return localizations.trn_invoice;
      default:
        return '';
    }
  }

  Future<void> _refreshTaskData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        return;
      }

      final taskId = taskData['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        return;
      }

      await SessionManager().onNetworkRequest();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = widget.isReport
          ? '$baseUrl5/transport/report?ts=$ts'
          : '$baseUrl5/transport/task?ts=$ts';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Connection': 'close',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);
        final dynamic data = json.decode(body);

        if (data is Map && data['error'] != null) {
          return;
        }

        List<dynamic> tasksList = [];
        if (data is List) {
          tasksList = data;
        } else if (data is Map && data['results'] is List) {
          tasksList = data['results'] as List<dynamic>;
        }

        final updatedTask = tasksList.firstWhere(
          (t) => t['id']?.toString() == taskId,
          orElse: () => null,
        );

        if (updatedTask != null) {
          setState(() {
            taskData = Map<String, dynamic>.from(updatedTask);
          });
        }
      }
    } catch (e) {
      print('Error refreshing task data: $e');
    }
  }

  String _formatDate(BuildContext context, String dateString) {
    try {
      final date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        final j = Jalali.fromDateTime(date);
        return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      case 'confirm':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    return _getStatusColor(status);
  }

  String _getStatusText(String status, AppLocalizations localizations) {
    switch (status) {
      case 'open':
        return localizations.sps_status_open;
      case 'assigned':
        return localizations.sps_status_assigned;
      case 'confirm':
        return localizations.sps_status_confirm;
      case 'done':
        return localizations.sps_status_done;
      case 'canceled':
        return localizations.sps_status_canceled;
      default:
        return status;
    }
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;
    final text = value.toString().trim();
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }

  bool _isValidAddress(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != '---';
  }

  Future<NeshanLatLng?> _currentDriverLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 6));

      final location = NeshanLatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return isPlausibleIranCoordinate(location) ? location : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startNavigation() async {
    final localizations = AppLocalizations.of(context)!;
    final mabda = (taskData['mabda'] ?? '---').toString();
    final maghsad = (taskData['maghsad'] ?? '---').toString();

    if (!_isValidAddress(mabda) || !_isValidAddress(maghsad)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.driver_route_invalid_address),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    const routingService = DriverRoutingService();

    setState(() => isRouting = true);

    try {
      final driverLocation = await _currentDriverLocation();

      final originResult = await routingService.resolveCargoAddress(
        mabda,
        driverLocation: driverLocation,
      );

      if (!geocodedCityMatchesAddress(
        result: originResult,
        address: mabda,
      )) {
        throw NeshanApiException(
          localizations.driver_route_geocode_city_mismatch,
        );
      }

      if (!isPlausibleIranCoordinate(originResult.location)) {
        throw NeshanApiException(
          localizations.driver_route_invalid_address,
        );
      }

      if (isClearlyWrongGeocodingResult(originResult, mabda)) {
        throw NeshanApiException(
          localizations.driver_route_invalid_address,
        );
      }

      final destinationResult = await routingService.resolveCargoAddress(
        maghsad,
        siblingResult: originResult,
        driverLocation: driverLocation,
      );

      if (!geocodedCityMatchesAddress(
        result: destinationResult,
        address: maghsad,
      )) {
        throw NeshanApiException(
          localizations.driver_route_geocode_city_mismatch,
        );
      }

      if (!isPlausibleIranCoordinate(destinationResult.location)) {
        throw NeshanApiException(
          localizations.driver_route_invalid_address,
        );
      }

      if (isClearlyWrongGeocodingResult(destinationResult, maghsad)) {
        throw NeshanApiException(
          localizations.driver_route_invalid_address,
        );
      }

      if (!mounted) return;

      if (kDebugMode) {
        debugPrint(
          'Geocode origin: ${originResult.location.latitude},'
          ' ${originResult.location.longitude}'
          ' city=${originResult.city}',
        );
        debugPrint(
          'Geocode destination: ${destinationResult.location.latitude},'
          ' ${destinationResult.location.longitude}'
          ' city=${destinationResult.city}',
        );
      }

      // Open the map as soon as endpoints are geocoded; routing continues on
      // the route screen so the driver is not kept waiting on two API calls.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverRouteScreen(
            originAddress: mabda,
            destinationAddress: maghsad,
            origin: originResult.location,
            destination: destinationResult.location,
            assignmentId: _assignmentId,
          ),
        ),
      );
    } on NeshanApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizeNeshanError(localizations, e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.driver_route_error),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isRouting = false);
      }
    }
  }

  Future<void> _completeTask() async {
    final localizations = AppLocalizations.of(context)!;

    final reportController = TextEditingController();
    final feeController = TextEditingController();
    PickedTransportAttachment? receipt;

    final _CompleteTaskFormResult? formResult =
        await showDialog<_CompleteTaskFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickReceipt() async {
              try {
                final FilePickerResult? result =
                    await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: kTransportAttachmentExtensions,
                  withData: true,
                  allowMultiple: false,
                );
                if (result == null || result.files.isEmpty) return;

                final PlatformFile file = result.files.single;
                if (!isAllowedTransportAttachmentName(file.name)) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.trn_attachment_invalid),
                    ),
                  );
                  return;
                }

                Uint8List? bytes = file.bytes;
                if (bytes == null && file.path != null) {
                  bytes = await readLocalFileBytes(file.path!);
                }
                if (bytes == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.trn_attachment_invalid),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  receipt = PickedTransportAttachment(
                    name: file.name,
                    bytes: bytes!,
                    path: file.path,
                  );
                });
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.trn_attachment_invalid),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(localizations.driver_enter_report),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: reportController,
                      decoration: InputDecoration(
                        labelText: localizations.driver_report,
                        hintText: localizations.driver_report,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 5,
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feeController,
                      decoration: InputDecoration(
                        labelText: localizations.driver_fee_received,
                        hintText: localizations.driver_fee_received_hint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandSeparatorInputFormatter()],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.driver_final_attachment,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.iranianGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (receipt != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file,
                            color: AppColors.lapisLazuli,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              receipt!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                localizations.driver_final_attachment_remove,
                            onPressed: () {
                              setDialogState(() => receipt = null);
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                    OutlinedButton.icon(
                      onPressed: pickReceipt,
                      icon: const Icon(
                        Icons.receipt_long,
                        color: AppColors.lapisLazuli,
                      ),
                      label: Text(
                        localizations.driver_final_attachment_pick,
                        style: const TextStyle(
                          color: AppColors.lapisLazuli,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.lapisLazuli),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizations.driver_final_attachment_hint,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(localizations.home_no),
                ),
                TextButton(
                  onPressed: () {
                    if (reportController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.driver_report_required),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    if (feeController.text.trim().isNotEmpty &&
                        parseGroupedInt(feeController.text) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.driver_fee_received_invalid,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _CompleteTaskFormResult(
                        report: reportController.text.trim(),
                        fee: parseGroupedInt(feeController.text),
                        receipt: receipt,
                      ),
                    );
                  },
                  child: Text(localizations.home_yes),
                ),
              ],
            );
          },
        );
      },
    );

    reportController.dispose();
    feeController.dispose();

    if (formResult == null || formResult.report.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(localizations.error_token_missing);
      }

      final taskId = taskData['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        throw Exception(localizations.error_task_id_missing);
      }

      await SessionManager().onNetworkRequest();

      final url = '$baseUrl5/transport/task/$taskId/confirm';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['report'] = formResult.report;
      if (formResult.fee != null) {
        request.fields['fee_received'] = formResult.fee!.toString();
      }
      if (formResult.receipt != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'driver_final_attachment',
            formResult.receipt!.bytes,
            filename: formResult.receipt!.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = utf8.decode(response.bodyBytes);
        final responseData = json.decode(body);
        final message =
            responseData['message']?.toString() ??
            localizations.driver_complete_task_success;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        Navigator.pop(context, true);
      } else {
        final body = utf8.decode(response.bodyBytes);
        final errorData = json.decode(body);
        final errorMessage =
            errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            localizations.driver_complete_task_error;
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(e, localizations),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    final String maghsad = (taskData['maghsad'] ?? '---').toString();
    final String mabda = (taskData['mabda'] ?? '---').toString();
    final String phone = (taskData['phone'] ?? '---').toString();
    final String description = (taskData['description'] ?? '---').toString();
    final String report = (taskData['report'] ?? '').toString();
    final String status = (taskData['status'] ?? 'open').toString();
    final String createdAt = (taskData['created_at'] ?? '').toString();
    final String productDescription = (taskData['product_description'] ?? '')
        .toString();
    final String outputNum = (taskData['output_number'] ?? '').toString();
    final String coordination = (taskData['coordination_person'] ?? '')
        .toString();
    final bool hasProductDescription = _hasValue(
      taskData['product_description'],
    );
    final bool hasOutputNum = _hasValue(taskData['output_number']);
    final bool hasCoordination = _hasValue(taskData['coordination_person']);
    final bool hasCustomer = _hasValue(taskData['customer']);
    final bool driverConfirm = taskData['driver_confirm'] ?? false;
    final bool customerConfirm = taskData['customer_confirm'] ?? false;
    final String paymentType = (taskData['payment_type'] ?? '').toString();
    final String customer = (taskData['customer'] ?? '').toString();
    // Handle price_transport - can be null, number, or string
    final String priceTransport = formatGroupedNumber(
      taskData['price_transport'],
    );
    final String feeReceived = formatGroupedNumber(
      taskData['fee_received'],
      fallback: '0',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.scale(base: 16, min: 12, max: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                        widget.isReport
                            ? localizations.driver_report_details
                            : localizations.driver_task_details,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
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
          ),
        ),
      ),
      body: Directionality(
        textDirection:
            AppLocalizations.of(context)!.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _refreshTaskData,
          color: AppColors.lapisLazuli,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ui.scale(base: 20, min: 16, max: 24),
              ui.scale(base: 20, min: 16, max: 24),
              ui.scale(base: 20, min: 16, max: 24),
              ui.scale(base: 20, min: 16, max: 24) +
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusBackgroundColor(status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getStatusText(status, localizations),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                _buildInfoItem(
                  context,
                  icon: Icons.location_city,
                  title: localizations.driver_mabda,
                  value: mabda,
                ),
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                _buildInfoItem(
                  context,
                  icon: Icons.location_on,
                  title: localizations.driver_maghsad,
                  value: maghsad,
                ),
                if (!widget.isReport &&
                    _isValidAddress(mabda) &&
                    _isValidAddress(maghsad)) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isRouting ? null : _startNavigation,
                      icon: isRouting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.lapisLazuli,
                              ),
                            )
                          : const Icon(Icons.directions, size: 20),
                      label: Text(
                        isRouting
                            ? localizations.driver_route_loading
                            : localizations.driver_navigate,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lapisLazuli,
                        side: BorderSide(
                          color: AppColors.lapisLazuli.withValues(alpha: 0.5),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: ui.scale(base: 14, min: 12, max: 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                _buildInfoItem(
                  context,
                  icon: Icons.phone,
                  title: localizations.driver_phone,
                  value: phone,
                  isPhone: true,
                ),
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                if (!widget.isReport) ...[
                  _buildInfoItem(
                    context,
                    icon: Icons.attach_money,
                    title: localizations.driver_price_transport,
                    value: priceTransport == '---'
                        ? '---'
                        : '$priceTransport ${localizations.sls_tooman}',
                  ),
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                ],
                _buildInfoItem(
                  context,
                  icon: Icons.attach_money,
                  title: localizations.driver_fee_received,
                  value: feeReceived == '---'
                      ? '---'
                      : '$feeReceived ${localizations.sls_tooman}',
                ),
                if (hasTransportAttachment(taskData)) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  buildTransportAttachmentSection(
                    context: context,
                    data: taskData,
                    isDownloading: isDownloadingAttachment,
                    onDownload: () async {
                      setState(() => isDownloadingAttachment = true);
                      try {
                        await downloadTransportAttachment(
                          context: context,
                          data: taskData,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => isDownloadingAttachment = false);
                        }
                      }
                    },
                  ),
                ],
                if (hasDriverFinalAttachment(taskData)) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  buildDriverFinalAttachmentSection(
                    context: context,
                    data: taskData,
                    isDownloading: isDownloadingFinalAttachment,
                    onDownload: () async {
                      setState(() => isDownloadingFinalAttachment = true);
                      try {
                        await downloadDriverFinalAttachment(
                          context: context,
                          data: taskData,
                        );
                      } finally {
                        if (mounted) {
                          setState(
                            () => isDownloadingFinalAttachment = false,
                          );
                        }
                      }
                    },
                  ),
                ],
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                _buildInfoItem(
                  context,
                  icon: Icons.check_circle,
                  title: localizations.driver_driver_confirm,
                  value: driverConfirm
                      ? localizations.driver_yes
                      : localizations.driver_no,
                ),
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                _buildInfoItem(
                  context,
                  icon: Icons.verified_user,
                  title: localizations.driver_customer_confirm,
                  value: customerConfirm
                      ? localizations.driver_yes
                      : localizations.driver_no,
                ),
                if (hasProductDescription) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  _buildInfoItem(
                    context,
                    icon: Icons.edit_document,
                    title: localizations.trn_product_description,
                    value: productDescription,
                  ),
                ],
                if (hasOutputNum) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  _buildInfoItem(
                    context,
                    icon: Icons.numbers,
                    title: localizations.trn_output_number,
                    value: outputNum,
                  ),
                ],
                if (hasCoordination) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  _buildInfoItem(
                    context,
                    icon: Icons.person,
                    title: localizations.trn_coordination_person,
                    value: coordination,
                  ),
                ],
                SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                _buildInfoItem(
                  context,
                  icon: Icons.payment,
                  title: localizations.trn_payment_type,
                  value: getpaymentLabel(paymentType),
                ),
                if (hasCustomer) ...[
                  SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                  _buildInfoItem(
                    context,
                    icon: Icons.person,
                    title: localizations.trn_customer,
                    value: customer,
                  ),
                ],
                SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                Text(
                  localizations.driver_description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]!
                          : AppColors.lapisLazuli.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black87,
                    ),
                  ),
                ),
                // Report section (only for reports)
                if (widget.isReport && report.isNotEmpty) ...[
                  SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                  Text(
                    localizations.driver_report,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[700]!
                            : AppColors.lapisLazuli.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      report,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.black87,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
                if (createdAt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.iranianGray.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.iranianGray,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${localizations.driver_created_at} ${_formatDate(context, createdAt)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.iranianGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Complete Task Button (only for missions when driver_confirm is false, not reports)
                if (!widget.isReport && driverConfirm == false)
                  Padding(
                    padding: EdgeInsets.only(
                      top: ui.scale(base: 24, min: 20, max: 28),
                      bottom: ui.scale(base: 16, min: 12, max: 20),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _completeTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapisLazuli,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: ui.scale(base: 16, min: 14, max: 18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    localizations.driver_complete_task,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    bool isPhone = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.lapisLazuli),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.iranianGray,
                  ),
                ),
                const SizedBox(height: 4),
                if (isPhone)
                  TappablePhone(
                    phone: value,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black87,
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
