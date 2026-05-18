import 'package:uzita/api_config.dart';

/// Whether the task has no technician assigned (`technician` is null / empty).
bool isTechnicianUnassigned(Map<String, dynamic> task) {
  final dynamic technician = task['technician'];
  if (technician == null) return true;
  if (technician is String) {
    final String value = technician.trim().toLowerCase();
    return value.isEmpty ||
        value == 'null' ||
        value == 'none' ||
        value == '---';
  }
  if (technician is Map) {
    final String username =
        (technician['username'] ?? technician['name'] ?? '')
            .toString()
            .trim();
    return username.isEmpty;
  }
  return false;
}

/// Display username for an assigned technician, or null if unassigned.
String? resolvedTechnicianUsername(Map<String, dynamic> task) {
  if (isTechnicianUnassigned(task)) return null;

  final dynamic technician = task['technician'];
  if (technician is String && technician.trim().isNotEmpty) {
    return technician.trim();
  }
  if (technician is Map) {
    final String? fromMap =
        technician['username']?.toString() ?? technician['name']?.toString();
    if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap.trim();
  }

  for (final key in ['technician_username', 'assigned_username', 'assigned_to']) {
    final dynamic value = task[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return null;
}

/// Org manager can assign when task is active and has no technician.
bool canAssignOrgTask(Map<String, dynamic> task) {
  final String status = (task['status'] ?? '').toString().toLowerCase();
  if (status == 'done' || status == 'canceled') return false;
  return isTechnicianUnassigned(task);
}

bool _isValidAttachmentPath(String path) {
  if (path.isEmpty) return false;
  final String lower = path.toLowerCase();
  return lower != 'null' && lower != 'none';
}

String? _parseAttachmentValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final String trimmed = raw.trim();
    return _isValidAttachmentPath(trimmed) ? trimmed : null;
  }
  if (raw is Map) {
    for (final String key in <String>[
      'url',
      'path',
      'file',
      'href',
      'link',
      'attachment',
    ]) {
      final String? nested = _parseAttachmentValue(raw[key]);
      if (nested != null) return nested;
    }
  }
  return null;
}

/// Raw attachment path/URL from task JSON (`attachment`, nested object, etc.).
String? taskAttachmentPath(Map<String, dynamic> task) {
  for (final String key in <String>[
    'attachment',
    'service_attachment',
    'file',
    'attachment_url',
    'file_url',
  ]) {
    final String? parsed = _parseAttachmentValue(task[key]);
    if (parsed != null) return parsed;
  }

  final dynamic attachments = task['attachments'];
  if (attachments is List) {
    for (final dynamic item in attachments) {
      final String? parsed = _parseAttachmentValue(item);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool taskHasAttachment(Map<String, dynamic> task) =>
    taskAttachmentPath(task) != null;

void mergeTaskAttachmentFields(
  Map<String, dynamic> target,
  Map<String, dynamic> source,
) {
  final String? path = taskAttachmentPath(source);
  if (path != null) {
    target['attachment'] = path;
  }
  final String? name = source['attachment_name']?.toString().trim();
  if (name != null && name.isNotEmpty) {
    target['attachment_name'] = name;
  }
}

String taskAttachmentDisplayName(Map<String, dynamic> task) {
  final String? name = task['attachment_name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;

  final String? path = taskAttachmentPath(task);
  if (path == null || path.isEmpty) return 'attachment';
  final Uri? uri = Uri.tryParse(path);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    return Uri.decodeComponent(uri.pathSegments.last);
  }
  final segments = path.split('/');
  return segments.isNotEmpty ? segments.last : path;
}

String taskAttachmentDownloadUrl(Map<String, dynamic> task) {
  final String? path = taskAttachmentPath(task);
  if (path == null || path.isEmpty) return '';
  return resolveTaskAttachmentUrl(path);
}

/// Parses list responses from `/technician/tasks` and `/technician-organ/tasks`.
List<dynamic> extractTechnicianTaskListPayload(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final String key in <String>['results', 'data', 'tasks', 'items']) {
      final dynamic value = data[key];
      if (value is List) return value;
    }
  }
  return <dynamic>[];
}

Map<String, dynamic>? findTechnicianTaskInPayload(
  dynamic data,
  String taskId,
) {
  for (final dynamic item in extractTechnicianTaskListPayload(data)) {
    if (item is Map && (item['id'] ?? '').toString() == taskId) {
      return normalizeTechnicianTask(Map<String, dynamic>.from(item));
    }
  }
  return null;
}

Map<String, dynamic> normalizeTechnicianTask(Map<String, dynamic> raw) {
  final Map<String, dynamic> t = Map<String, dynamic>.from(raw);
  t['status'] = (t['status'] ?? '').toString().toLowerCase();

  final dynamic technician = t['technician'];
  if (technician is String && technician.trim().isNotEmpty) {
    t['technician_username'] = technician.trim();
  } else if (technician is Map) {
    final String? fromMap =
        technician['username']?.toString() ?? technician['name']?.toString();
    if (fromMap != null && fromMap.trim().isNotEmpty) {
      t['technician_username'] = fromMap.trim();
    }
  }

  if (t['technician_confirm'] is String) {
    t['technician_confirm'] =
        t['technician_confirm'].toString().toLowerCase() == 'true';
  }
  if (t['customer_confirm'] is String) {
    t['customer_confirm'] =
        t['customer_confirm'].toString().toLowerCase() == 'true';
  }
  if (t['warranty'] is String) {
    t['warranty'] = t['warranty'].toString().toLowerCase() == 'true';
  }

  final String? attachmentPath = taskAttachmentPath(t);
  if (attachmentPath != null) {
    t['attachment'] = attachmentPath;
  }

  final pieces = t['pieces'];
  if (pieces is List && pieces.isNotEmpty) {
    t['piece_ids'] = pieces
        .whereType<Map>()
        .map((p) => p['id'])
        .where((id) => id != null)
        .toList();
  }
  final tariffs = t['tariffs'];
  if (tariffs is List && tariffs.isNotEmpty) {
    t['tariff_ids'] = tariffs
        .whereType<Map>()
        .map((p) => p['id'])
        .where((id) => id != null)
        .toList();
  }

  return t;
}
