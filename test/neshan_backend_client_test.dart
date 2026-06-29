import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/services/neshan_backend_client.dart';
import 'package:uzita/utils/neshan_error_codes.dart';

void main() {
  group('NeshanBackendClient.exceptionFromResponse', () {
    test('maps 401 to session expired, not proxy missing', () {
      final error = NeshanBackendClient.exceptionFromResponse(401, '{}');
      expect(error?.neshanStatus, NeshanErrorCodes.backendUnauthorized);
    });

    test('maps proxied Neshan 484 to ApiWhiteListError', () {
      const body = '''
{"status":"ApiWhiteListError","code":484,"message":"whitelist error"}
''';
      final error = NeshanBackendClient.exceptionFromResponse(484, body);
      expect(error?.neshanStatus, 'ApiWhiteListError');
    });

    test('maps 404 to BackendProxyNotFound', () {
      final error = NeshanBackendClient.exceptionFromResponse(404, '{}');
      expect(error?.neshanStatus, 'BackendProxyNotFound');
    });

    test('returns null for 200', () {
      final error = NeshanBackendClient.exceptionFromResponse(200, '{}');
      expect(error, isNull);
    });
  });
}
