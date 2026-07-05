import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uzita/services/session_manager.dart';

export 'package:http/http.dart'
    show
        Response,
        StreamedResponse,
        ByteStream,
        MultipartFile,
        MultipartRequest;

bool _shouldEndSessionOnUnauthorized(Uri url) {
  final String path = url.path.toLowerCase();
  if (path.endsWith('/login') || path.endsWith('/login/')) {
    return false;
  }
  if (path.contains('register') ||
      path.contains('verify') ||
      path.contains('otp')) {
    return false;
  }
  return true;
}

Future<void> _handleUnauthorized(Uri url, int statusCode) async {
  if (statusCode == 401 && _shouldEndSessionOnUnauthorized(url)) {
    await SessionManager().endSession();
  }
}

Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.get(url, headers: headers);
  await _handleUnauthorized(url, resp.statusCode);
  return resp;
}

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.post(
    url,
    headers: headers,
    body: body,
    encoding: encoding,
  );
  await _handleUnauthorized(url, resp.statusCode);
  return resp;
}

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.put(
    url,
    headers: headers,
    body: body,
    encoding: encoding,
  );
  await _handleUnauthorized(url, resp.statusCode);
  return resp;
}

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.delete(
    url,
    headers: headers,
    body: body,
    encoding: encoding,
  );
  await _handleUnauthorized(url, resp.statusCode);
  return resp;
}

Future<http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.patch(
    url,
    headers: headers,
    body: body,
    encoding: encoding,
  );
  await _handleUnauthorized(url, resp.statusCode);
  return resp;
}
