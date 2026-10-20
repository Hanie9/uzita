import 'package:uzita/api_config.dart';

class ReportPagePayload {
  const ReportPagePayload({
    required this.results,
    this.nextUrl,
    this.totalCount,
  });

  final List<dynamic> results;
  final String? nextUrl;
  final int? totalCount;
}

/// Reads a DRF-style page (`results` + `next`) or a numeric next page.
ReportPagePayload parseReportPage(
  dynamic data, {
  required String listEndpoint,
}) {
  if (data is List) {
    return ReportPagePayload(results: data);
  }
  if (data is! Map) {
    return const ReportPagePayload(results: <dynamic>[]);
  }

  final dynamic results = data['results'];
  return ReportPagePayload(
    results: results is List ? results : <dynamic>[],
    nextUrl: _resolveNextUrl(data, listEndpoint),
    totalCount: _asInt(data['count'] ?? data['total']),
  );
}

List<Map<String, dynamic>> appendUniqueReports(
  List<dynamic> current,
  List<dynamic> incoming,
) {
  final Set<String> seen = <String>{};
  final List<Map<String, dynamic>> merged = <Map<String, dynamic>>[];

  void add(dynamic item) {
    if (item is! Map) return;
    final Map<String, dynamic> map = Map<String, dynamic>.from(item);
    final String id = (map['id'] ?? '').toString();
    if (id.isNotEmpty && !seen.add(id)) return;
    merged.add(map);
  }

  for (final dynamic item in current) {
    add(item);
  }
  for (final dynamic item in incoming) {
    add(item);
  }
  return merged;
}

String? _resolveNextUrl(Map<dynamic, dynamic> data, String listEndpoint) {
  dynamic next = data['next'];
  final dynamic pagination = data['pagination'];
  if (_isBlank(next) && pagination is Map) {
    next = pagination['next'] ?? pagination['next_page'];
  }
  next ??= data['next_page'];

  if (next is num) {
    return _pageUrl(listEndpoint, next.toInt());
  }

  if (next is String) {
    final String raw = next.trim();
    if (_isBlank(raw)) return null;
    final int? pageNumber = int.tryParse(raw);
    if (pageNumber != null) return _pageUrl(listEndpoint, pageNumber);
    final Uri? parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return Uri.parse(apiBaseUrl).resolve(raw).toString();
  }

  final int? page = _asInt(data['page'] ?? data['current_page']);
  final int? pages = _asInt(
    data['total_pages'] ?? data['num_pages'] ?? data['pages'],
  );
  if (page != null && pages != null && page < pages) {
    return _pageUrl(listEndpoint, page + 1);
  }
  return null;
}

String _pageUrl(String listEndpoint, int page) {
  final Uri endpoint = Uri.parse(listEndpoint);
  return endpoint
      .replace(
        queryParameters: <String, String>{
          ...endpoint.queryParameters,
          'page': '$page',
        },
      )
      .toString();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

bool _isBlank(dynamic value) {
  if (value == null) return true;
  final String text = value.toString().trim().toLowerCase();
  return text.isEmpty || text == 'null';
}
