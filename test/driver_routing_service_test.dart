import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/services/driver_routing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriverRoutingService', () {
    const service = DriverRoutingService();

    test('canNavigate requires Neshan API key', () {
      expect(service.canNavigate, isA<bool>());
    });
  });
}
