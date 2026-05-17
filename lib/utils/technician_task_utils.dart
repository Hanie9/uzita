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
