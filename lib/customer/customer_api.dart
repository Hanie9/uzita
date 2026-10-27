import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/phone_utils.dart';

class CustomerPage {
  const CustomerPage({
    required this.results,
    required this.count,
    required this.numPages,
    required this.currentPage,
  });

  final List<Map<String, dynamic>> results;
  final int count;
  final int numPages;
  final int currentPage;

  bool get hasNext => currentPage < numPages;
}

class CustomerCallException implements Exception {
  CustomerCallException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() => message;
}

class PickedCustomerFile {
  const PickedCustomerFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// When the typed username is a mobile number with a prefix, the account
/// username is the 10-digit form. Returns null when no alternate is needed.
String? customerLoginRetryUsername(String entered) {
  final String trimmed = entered.trim();
  final String? normalized = normalizeCustomerPhone(trimmed);
  if (normalized == null || normalized == trimmed) return null;
  return normalized;
}

/// Stored usernames omit a leading zero, so `09...` and `9...` are one account.
bool customerLoginNamesMatch(String returned, String entered) {
  final String left = returned.trim().toLowerCase();
  final String right = entered.trim().toLowerCase();
  if (left.isEmpty || left == right) return left.isNotEmpty && left == right;
  final String? a = normalizeCustomerPhone(returned);
  final String? b = normalizeCustomerPhone(entered);
  return a != null && a == b;
}

/// Mobile numbers are stored as 10 digits, without a leading zero.
String? normalizeCustomerPhone(String raw) {
  String digits = normalizePhoneDigits(raw);
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  }
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('98') && digits.length == 12) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length != 10) return null;
  return digits;
}

bool customerFlag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

String? customerText(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    final dynamic named =
        value['full_name'] ??
        value['name'] ??
        value['username'] ??
        value['title'];
    if (named != null && named.toString().trim().isNotEmpty) {
      return named.toString().trim();
    }
    if (value.isEmpty) return null;
  }
  if (value is List) {
    if (value.isEmpty) return null;
    return value
        .map((item) => customerText(item) ?? item.toString())
        .where((item) => item.trim().isNotEmpty)
        .join('، ');
  }
  final String text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'None') return null;
  return text;
}

bool customerHasFile(dynamic value) {
  final String? text = customerText(value);
  return text != null && text != '-' && text != '—';
}

String customerErrorMessage(dynamic data, String fallback) {
  if (data is Map) {
    final dynamic detail = data['detail'] ?? data['error'] ?? data['message'];
    if (detail is String && detail.trim().isNotEmpty && data.length == 1) {
      return detail.trim();
    }
    final List<String> parts = <String>[];
    for (final MapEntry<dynamic, dynamic> entry in data.entries) {
      final dynamic value = entry.value;
      if (value is List) {
        for (final dynamic item in value) {
          final String text = item.toString().trim();
          if (text.isNotEmpty) parts.add(text);
        }
      } else if (value is String && value.trim().isNotEmpty) {
        if (entry.key == 'message' && data['data'] != null) continue;
        parts.add(value.trim());
      }
    }
    if (parts.isNotEmpty) return parts.join('\n');
  } else if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  return fallback;
}

Map<String, dynamic> customerObject(dynamic data) {
  if (data is Map && data['data'] is Map) {
    return Map<String, dynamic>.from(data['data'] as Map);
  }
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> customerReplies(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        value = json.decode(trimmed);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    } else {
      return <Map<String, dynamic>>[];
    }
  }
  if (value is Map) {
    value = value['results'] ?? value['replies'] ?? <dynamic>[];
  }
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<Map<String, String>> _authHeaders({bool json = false}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');
  if (token == null || token.isEmpty) {
    throw CustomerCallException('auth');
  }
  return <String, String>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json; charset=utf-8',
  };
}

Uri customerUri(String path, [Map<String, String>? query]) {
  final String normalized = path.startsWith('/') ? path : '/$path';
  return Uri.parse(
    '$apiBaseUrl$normalized',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);
}

Future<dynamic> _decode(http.Response response, String fallback) async {
  final String body = utf8.decode(response.bodyBytes);
  dynamic data;
  if (body.trim().isNotEmpty) {
    try {
      data = json.decode(body);
    } catch (_) {
      data = body;
    }
  }
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return data;
  }
  throw CustomerCallException(
    customerErrorMessage(data, fallback),
    statusCode: response.statusCode,
    data: data,
  );
}

Future<dynamic> customerGet(String path, {String fallback = ''}) async {
  final http.Response response = await http.get(
    customerUri(path),
    headers: await _authHeaders(),
  );
  return _decode(response, fallback);
}

Future<CustomerPage> customerList(
  String path, {
  int page = 1,
  String fallback = '',
}) async {
  final http.Response response = await http.get(
    customerUri(path, <String, String>{'page': '$page', 'page_size': '30'}),
    headers: await _authHeaders(),
  );
  final dynamic data = await _decode(response, fallback);
  if (data is List) {
    return CustomerPage(
      results: data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      count: data.length,
      numPages: 1,
      currentPage: 1,
    );
  }
  final Map<String, dynamic> map = data is Map
      ? Map<String, dynamic>.from(data)
      : <String, dynamic>{};
  final List<dynamic> raw = map['results'] is List
      ? map['results'] as List<dynamic>
      : <dynamic>[];
  return CustomerPage(
    results: raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
    count: int.tryParse('${map['count']}') ?? raw.length,
    numPages: int.tryParse('${map['num_pages']}') ?? 1,
    currentPage: int.tryParse('${map['current_page']}') ?? page,
  );
}

Future<dynamic> customerSendJson(
  String method,
  String path,
  Map<String, dynamic> body, {
  String fallback = '',
}) async {
  final Uri uri = customerUri(path);
  final Map<String, String> headers = await _authHeaders(json: true);
  final String encoded = json.encode(body);
  final http.Response response = switch (method) {
    'PUT' => await http.put(uri, headers: headers, body: encoded),
    'PATCH' => await http.patch(uri, headers: headers, body: encoded),
    'DELETE' => await http.delete(uri, headers: headers, body: encoded),
    _ => await http.post(uri, headers: headers, body: encoded),
  };
  return _decode(response, fallback);
}

Future<dynamic> customerDelete(String path, {String fallback = ''}) async {
  final http.Response response = await http.delete(
    customerUri(path),
    headers: await _authHeaders(),
  );
  return _decode(response, fallback);
}

Future<dynamic> customerMultipart({
  required String method,
  required String path,
  Map<String, String> fields = const <String, String>{},
  Map<String, List<String>> repeatedFields = const <String, List<String>>{},
  Map<String, PickedCustomerFile> files = const <String, PickedCustomerFile>{},
  String fallback = '',
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');
  if (token == null || token.isEmpty) {
    throw CustomerCallException('auth');
  }

  await SessionManager().onNetworkRequest();
  final http.MultipartRequest request = http.MultipartRequest(
    method,
    customerUri(path),
  );
  request.headers['Authorization'] = 'Bearer $token';
  request.headers['Accept'] = 'application/json';
  request.fields.addAll(fields);
  for (final MapEntry<String, List<String>> entry in repeatedFields.entries) {
    for (final String value in entry.value) {
      request.files.add(http.MultipartFile.fromString(entry.key, value));
    }
  }
  for (final MapEntry<String, PickedCustomerFile> entry in files.entries) {
    request.files.add(
      http.MultipartFile.fromBytes(
        entry.key,
        entry.value.bytes,
        filename: entry.value.name,
      ),
    );
  }

  final http.StreamedResponse streamed = await request.send();
  final http.Response response = await http.Response.fromStream(streamed);
  if (response.statusCode == 401) {
    await SessionManager().endSession();
  }
  return _decode(response, fallback);
}

Future<Map<String, dynamic>> registerCustomer({
  required String phone,
  required String firstName,
  required String lastName,
  required String password,
  required String passwordConfirm,
  String fallback = '',
}) async {
  final http.Response response = await http.post(
    Uri.parse('$apiBaseUrl/register'),
    headers: const <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    },
    body: json.encode(<String, String>{
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'password_confirm': passwordConfirm,
    }),
  );
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return <String, dynamic>{'ok': true};
  }
  dynamic data;
  final String body = utf8.decode(response.bodyBytes);
  if (body.trim().isNotEmpty) {
    try {
      data = json.decode(body);
    } catch (_) {
      data = body;
    }
  }
  throw CustomerCallException(
    customerErrorMessage(data, fallback),
    statusCode: response.statusCode,
    data: data,
  );
}

Future<void> signInCustomer({
  required String phone,
  required String password,
  required String firstName,
  required String lastName,
  String fallback = '',
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? savedUsername = prefs.getString('saved_username');
  final String? language = prefs.getString('selectedLanguage');
  final bool? darkMode = prefs.getBool('darkModeEnabled');
  final double? textSize = prefs.getDouble('textSize');
  final bool? notifications = prefs.getBool('notificationsEnabled');
  await prefs.clear();
  if (savedUsername != null && savedUsername.isNotEmpty) {
    await prefs.setString('saved_username', savedUsername);
  }
  if (language != null && language.isNotEmpty) {
    await prefs.setString('selectedLanguage', language);
  }
  if (darkMode != null) await prefs.setBool('darkModeEnabled', darkMode);
  if (textSize != null) await prefs.setDouble('textSize', textSize);
  if (notifications != null) {
    await prefs.setBool('notificationsEnabled', notifications);
  }

  final http.Response response = await http.post(
    Uri.parse('$apiBaseUrl/login/'),
    headers: const <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    },
    body: json.encode(<String, String>{
      'username': phone,
      'password': password,
    }),
  );
  dynamic data;
  final String body = utf8.decode(response.bodyBytes);
  if (body.trim().isNotEmpty) {
    try {
      data = json.decode(body);
    } catch (_) {
      data = body;
    }
  }
  if (response.statusCode != 200 || data is! Map) {
    throw CustomerCallException(
      customerErrorMessage(data, fallback),
      statusCode: response.statusCode,
      data: data,
    );
  }

  final String token = (data['token'] ?? '').toString();
  if (token.isEmpty) {
    throw CustomerCallException(fallback.isEmpty ? 'auth' : fallback);
  }
  await prefs.setString('token', token);
  await prefs.setString('phone', (data['phone'] ?? phone).toString());
  await prefs.setString('username', phone);
  await prefs.setString('first_name', firstName);
  await prefs.setString('last_name', lastName);
  await prefs.setInt(
    'login_at_epoch_ms',
    DateTime.now().millisecondsSinceEpoch,
  );

  try {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final http.Response userResponse = await http.get(
      Uri.parse('$apiBaseUrl/load_data_user/?ts=$ts'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache',
      },
    );
    if (userResponse.statusCode == 200) {
      final dynamic userData = json.decode(utf8.decode(userResponse.bodyBytes));
      if (userData is Map) {
        final dynamic user = userData['user'];
        await prefs.setInt('level', int.tryParse('${userData['level']}') ?? 2);
        await prefs.setBool('active', userData['active'] == true);
        await prefs.setBool('modir', userData['modir'] == true);
        await prefs.setBool('is_warehouse', userData['is_warehouse'] == true);
        await prefs.setString(
          'organ_type',
          (userData['organ_type'] ?? 'customer').toString(),
        );
        if (user is Map) {
          final String returned = (user['username'] ?? phone).toString();
          if (returned.isNotEmpty) await prefs.setString('username', returned);
          final String serverFirst = (user['first_name'] ?? '')
              .toString()
              .trim();
          final String serverLast = (user['last_name'] ?? '').toString().trim();
          if (serverFirst.isNotEmpty) {
            await prefs.setString('first_name', serverFirst);
          }
          if (serverLast.isNotEmpty) {
            await prefs.setString('last_name', serverLast);
          }
        }
      }
    }
  } catch (_) {}

  if ((prefs.getString('organ_type') ?? '').isEmpty) {
    await prefs.setString('organ_type', 'customer');
  }
  if (prefs.getInt('level') == null) await prefs.setInt('level', 2);
  await SessionManager().startSession();
}
