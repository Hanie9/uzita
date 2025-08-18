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

Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
  await SessionManager().onNetworkRequest();
  final resp = await http.get(url, headers: headers);
  if (resp.statusCode == 401) {
    await SessionManager().endSession();
  }
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
  if (resp.statusCode == 401) {
    await SessionManager().endSession();
  }
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
  if (resp.statusCode == 401) {
    await SessionManager().endSession();
  }
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
  if (resp.statusCode == 401) {
    await SessionManager().endSession();
  }
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
  if (resp.statusCode == 401) {
    await SessionManager().endSession();
  }
  return resp;
}
