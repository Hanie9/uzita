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

/// Shared parsing for technician task JSON (organ + personal lists).
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
