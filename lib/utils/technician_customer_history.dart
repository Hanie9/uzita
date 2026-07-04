import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/technician_task_utils.dart';

/// Digits-only phone for `/technician-organ/tasks/{phone}`.
String normalizeCustomerPhoneForHistory(String raw) {
  return raw.replaceAll(RegExp(r'\D'), '');
}

List<Map<String, dynamic>> parseCustomerHistoryPayload(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map(
          (dynamic item) =>
              normalizeTechnicianTask(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
  if (data is Map) {
    if (data['error'] != null) return <Map<String, dynamic>>[];
    for (final String key in <String>[
      'tasks',
      'missions',
      'results',
      'data',
      'history',
      'service_history',
      'items',
    ]) {
      final dynamic value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map(
              (dynamic item) =>
                  normalizeTechnicianTask(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    }
  }
  return <Map<String, dynamic>>[];
}

Future<List<Map<String, dynamic>>> fetchCustomerServiceHistory(
  String phone,
) async {
  final String normalized = normalizeCustomerPhoneForHistory(phone);
  if (normalized.isEmpty) return <Map<String, dynamic>>[];

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');
  if (token == null || token.isEmpty) return <Map<String, dynamic>>[];

  await SessionManager().onNetworkRequest();

  final int ts = DateTime.now().millisecondsSinceEpoch;
  final Uri url = Uri.parse(
    '$apiBaseUrl/technician-organ/tasks/$normalized?ts=$ts',
  );

  final http.Response response = await http.get(
    url,
    headers: <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('history_http_${response.statusCode}');
  }

  final dynamic data = json.decode(utf8.decode(response.bodyBytes));
  final List<Map<String, dynamic>> tasks = parseCustomerHistoryPayload(data);
  tasks.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime da = DateTime.tryParse(
          (a['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime db = DateTime.tryParse(
          (b['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return tasks;
}

String _formatHistoryDate(String? raw, BuildContext context) {
  if (raw == null || raw.trim().isEmpty) return '---';
  try {
    final DateTime date = DateTime.parse(raw).toLocal();
    final String datePart;
    if (Localizations.localeOf(context).languageCode == 'en') {
      datePart =
          '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } else {
      final Jalali j = Jalali.fromDateTime(date);
      datePart =
          '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
    }
    final String timePart =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$datePart $timePart';
  } catch (_) {
    return raw;
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'done':
      return Colors.green;
    case 'canceled':
      return Colors.red;
    case 'suspended':
      return Colors.grey.shade700;
    case 'confirm':
      return Colors.blue;
    default:
      return Colors.orange;
  }
}

String _statusLabel(String status, AppLocalizations loc) {
  switch (status.toLowerCase()) {
    case 'open':
      return loc.sps_status_open;
    case 'assigned':
      return loc.sps_status_assigned;
    case 'suspended':
      return loc.sps_status_suspended;
    case 'confirm':
      return loc.sps_status_confirm;
    case 'done':
      return loc.sps_status_done;
    case 'canceled':
      return loc.sps_status_canceled;
    default:
      return status;
  }
}

String _taskSubject(Map<String, dynamic> task) {
  final dynamic subjectsRaw = task['subjects'];
  if (subjectsRaw is List && subjectsRaw.isNotEmpty) {
    return subjectsRaw
        .map((dynamic e) => e.toString())
        .where((String s) => s.isNotEmpty)
        .join('، ');
  }
  final String title = (task['title'] ?? '').toString().trim();
  return title.isEmpty ? '---' : title;
}

Future<void> showCustomerServiceHistorySheet({
  required BuildContext context,
  required String customerPhone,
  String? customerName,
  String? currentTaskId,
}) async {
  final AppLocalizations loc = AppLocalizations.of(context)!;
  final String displayPhone = customerPhone.trim();
  final String? name = customerName?.trim();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _CustomerHistorySheet(
        customerPhone: displayPhone,
        customerName: name,
        currentTaskId: currentTaskId,
        loc: loc,
      );
    },
  );
}

class _CustomerHistorySheet extends StatefulWidget {
  const _CustomerHistorySheet({
    required this.customerPhone,
    required this.customerName,
    required this.currentTaskId,
    required this.loc,
  });

  final String customerPhone;
  final String? customerName;
  final String? currentTaskId;
  final AppLocalizations loc;

  @override
  State<_CustomerHistorySheet> createState() => _CustomerHistorySheetState();
}

class _CustomerHistorySheetState extends State<_CustomerHistorySheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = <Map<String, dynamic>>[];

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
      final List<Map<String, dynamic>> tasks =
          await fetchCustomerServiceHistory(widget.customerPhone);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.loc.tech_customer_history_error;
      });
    }
  }

  void _openTask(Map<String, dynamic> task) {
    final String status = (task['status'] ?? 'open').toString().toLowerCase();
    final Map<String, dynamic> taskToSend =
        normalizeTechnicianTask(Map<String, dynamic>.from(task));
    taskToSend['from_organ_assign_list'] = status != 'done';
    taskToSend['from_reports_list'] = status == 'done';
    Navigator.of(context).pop();
    Navigator.pushNamed(
      context,
      '/technician-task-detail',
      arguments: taskToSend,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: AppColors.lapisLazuli,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.loc.tech_customer_service_history,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.customerName != null &&
                                  widget.customerName!.isNotEmpty
                              ? '${widget.customerName} · ${widget.customerPhone}'
                              : widget.customerPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${_tasks.length} ${widget.loc.tech_mission}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lapisLazuli,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: _buildBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: Colors.red[400], size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              child: Text(widget.loc.tech_customer_history_retry),
            ),
          ],
        ),
      );
    }
    if (_tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          widget.loc.tech_customer_history_empty,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> task = _tasks[index];
        final String taskId = (task['id'] ?? '').toString();
        final String status = (task['status'] ?? 'open').toString();
        final Color statusColor = _statusColor(status);
        final String? technician = resolvedTechnicianUsername(task);
        final bool isCurrent =
            widget.currentTaskId != null &&
            widget.currentTaskId!.isNotEmpty &&
            taskId == widget.currentTaskId;

        return Material(
          color: isCurrent
              ? AppColors.lapisLazuli.withValues(alpha: 0.08)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openTask(task),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppColors.lapisLazuli
                      : theme.dividerColor.withValues(alpha: 0.35),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _statusLabel(status, widget.loc),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (isCurrent) ...<Widget>[
                        const SizedBox(width: 8),
                        Text(
                          widget.loc.tech_customer_history_current,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _taskSubject(task),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatHistoryDate(
                            (task['created_at'] ?? '').toString(),
                            context,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (technician != null && technician.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${widget.loc.tech_assigned_to}: $technician',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
