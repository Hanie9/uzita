import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/file_download_utils.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/number_format_utils.dart';
import 'package:uzita/utils/task_attachment_download.dart';
import 'package:uzita/utils/technician_task_utils.dart';

enum TaskAccountingKind { driver, technician }

Future<void> showTaskAccountingSheet(
  BuildContext context,
  TaskAccountingKind kind,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return TaskAccountingSheet(kind: kind);
    },
  );
}

class TaskAccountingSheet extends StatefulWidget {
  const TaskAccountingSheet({super.key, required this.kind});

  final TaskAccountingKind kind;

  @override
  State<TaskAccountingSheet> createState() => _TaskAccountingSheetState();
}

enum _ExcelDownloadStatus { idle, loading, success, failed }

class _TaskAccountingSheetState extends State<TaskAccountingSheet> {
  bool _loading = true;
  _ExcelDownloadStatus _downloadStatus = _ExcelDownloadStatus.idle;
  String? _error;
  Map<String, dynamic>? _data;

  bool get _isDriver => widget.kind == TaskAccountingKind.driver;

  String get _accountingPath => _isDriver
      ? '/transport/report/taskaccounting'
      : '/technician/reports/taskaccounting';

  String get _excelPath =>
      _isDriver ? '/transport/report/excel' : '/technician/reports/excel';

  String get _excelFileName =>
      _isDriver ? 'driver_reports.xlsx' : 'technician_reports.xlsx';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context)!.accounting_error;
        });
        return;
      }

      await SessionManager().onNetworkRequest();
      if (!mounted) return;

      final int ts = DateTime.now().millisecondsSinceEpoch;
      final http.Response response = await http.get(
        Uri.parse('$baseUrl5$_accountingPath?ts=$ts'),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Accept': 'application/json',
          'Connection': 'close',
        },
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context)!.accounting_error;
        });
        return;
      }

      final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['error'] != null) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context)!.accounting_error;
        });
        return;
      }

      setState(() {
        _data = Map<String, dynamic>.from(decoded);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context)!.accounting_error;
      });
    }
  }

  Future<void> _downloadExcel() async {
    if (_downloadStatus == _ExcelDownloadStatus.loading) return;
    setState(() => _downloadStatus = _ExcelDownloadStatus.loading);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      await SessionManager().onNetworkRequest();
      if (!mounted) return;

      final http.Response response = await _authorizedGet(
        '$baseUrl5$_excelPath?ts=${DateTime.now().millisecondsSinceEpoch}',
        token,
      );
      if (!mounted) return;

      final List<int> bytes = await _excelBytes(response, token);
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() => _downloadStatus = _ExcelDownloadStatus.failed);
        return;
      }

      final String? contentType = contentTypeFromHeaders(response.headers);
      final String fileName = _excelDownloadName(
        parseHttpDownloadFileName(
          response.headers,
          defaultName: _excelFileName,
        ),
        bytes,
        contentType,
      );
      await saveTaskAttachmentFile(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() => _downloadStatus = _ExcelDownloadStatus.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloadStatus = _ExcelDownloadStatus.failed);
    }
  }

  Future<http.Response> _authorizedGet(String url, String? token) {
    return http.get(
      Uri.parse(url),
      headers: <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': '*/*',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
  }

  Future<List<int>> _excelBytes(http.Response response, String? token) async {
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return <int>[];
    }

    final String? contentType = contentTypeFromHeaders(response.headers);
    if (looksLikeSpreadsheet(
      bytes: response.bodyBytes,
      contentType: contentType,
    )) {
      return response.bodyBytes;
    }
    if (looksLikeDownloadErrorBody(response.bodyBytes)) {
      final String? nestedUrl = _fileUrlFromJson(response.bodyBytes);
      if (nestedUrl == null) return <int>[];
      final http.Response nested = await _authorizedGet(
        resolveTaskAttachmentUrl(nestedUrl),
        token,
      );
      if (nested.statusCode != 200 || nested.bodyBytes.isEmpty) {
        return <int>[];
      }
      if (looksLikeDownloadErrorBody(nested.bodyBytes) &&
          !looksLikeSpreadsheet(
            bytes: nested.bodyBytes,
            contentType: contentTypeFromHeaders(nested.headers),
          )) {
        return <int>[];
      }
      return nested.bodyBytes;
    }
    return response.bodyBytes;
  }

  String? _fileUrlFromJson(List<int> bytes) {
    try {
      final dynamic decoded = json.decode(utf8.decode(bytes));
      if (decoded is String) return _asFileUrl(decoded);
      if (decoded is Map) {
        for (final dynamic value in decoded.values) {
          final String? url = value is String ? _asFileUrl(value) : null;
          if (url != null) return url;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _asFileUrl(String value) {
    final String text = value.trim();
    final String lower = text.toLowerCase();
    if (text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('/media/') ||
        text.startsWith('/api/') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.csv')) {
      return text;
    }
    return null;
  }

  String _excelDownloadName(String name, List<int> bytes, String? contentType) {
    final String resolved = ensureDownloadExtension(
      name,
      contentType ??
          (looksLikeLegacyExcel(bytes)
              ? 'application/vnd.ms-excel'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    );
    final String lower = resolved.toLowerCase();
    if (lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.csv')) {
      return resolved;
    }
    return '$resolved.xlsx';
  }

  Widget _buildDownloadButton(AppLocalizations loc) {
    final bool loading = _downloadStatus == _ExcelDownloadStatus.loading;
    final bool success = _downloadStatus == _ExcelDownloadStatus.success;
    final bool failed = _downloadStatus == _ExcelDownloadStatus.failed;
    final Color background = success
        ? const Color(0xFF1B7F4E)
        : failed
        ? const Color(0xFFC0392B)
        : AppColors.lapisLazuli;
    final String label = success
        ? loc.accounting_download_done
        : failed
        ? loc.accounting_download_failed
        : loc.accounting_download_excel;
    final IconData icon = success
        ? Icons.check_rounded
        : failed
        ? Icons.error_outline_rounded
        : Icons.file_download_outlined;

    return FilledButton.icon(
      onPressed: loading ? null : _downloadExcel,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool? _balanceOf(Map<String, dynamic> data) {
    final dynamic value = data['balance'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  String _money(dynamic value, String toman) {
    final String formatted = formatGroupedNumber(value);
    if (formatted == '---') return formatted;
    return '$formatted $toman';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final bool isEnglish =
        Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).selectedLanguage ==
        'en';
    final ThemeData theme = Theme.of(context);
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.iranianGray.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.lapisLazuli,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.accounting_title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.lapisLazuli,
                              ),
                              const SizedBox(height: 16),
                              Text(loc.accounting_loading),
                            ],
                          ),
                        )
                      : _error != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: Text(loc.accounting_retry),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.lapisLazuli,
                                  side: const BorderSide(
                                    color: AppColors.lapisLazuli,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildContent(loc),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations loc) {
    final Map<String, dynamic> data = _data ?? <String, dynamic>{};
    final bool? balance = _balanceOf(data);
    final bool creditor = balance == true;
    final Color statusColor = balance == null
        ? AppColors.lapisLazuli
        : (creditor ? const Color(0xFF1B7F4E) : const Color(0xFFC0392B));
    final String statusText = balance == null
        ? ''
        : (_isDriver
              ? (creditor
                    ? loc.accounting_driver_creditor
                    : loc.accounting_driver_debtor)
              : (creditor
                    ? loc.accounting_tech_creditor
                    : loc.accounting_tech_debtor));
    final dynamic net = _isDriver
        ? data['TaskAccounting']
        : data['company_profit'];
    final String toman = loc.sls_tooman;

    final List<(String, dynamic)> rows = _isDriver
        ? <(String, dynamic)>[
            (loc.accounting_driver_total_direct, data['total_direct']),
            (loc.accounting_driver_direct_loss, data['direct_loss']),
            (loc.accounting_driver_total_invoice, data['total_invoice']),
          ]
        : <(String, dynamic)>[
            (loc.accounting_tech_price_sum, data['price_sum']),
            (loc.accounting_tech_price_sum_loss, data['price_sum_loss']),
            (loc.accounting_tech_price_warranty, data['price_warranty']),
            (
              loc.accounting_tech_price_warranty_profit,
              data['price_warranty_profit'],
            ),
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.accounting_net,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(net, toman),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((row) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _money(row.$2, toman),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          _buildDownloadButton(loc),
        ],
      ),
    );
  }
}
