import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/validated_network_tile_provider.dart';

void main() {
  group('isRasterImageBytes', () {
    test('accepts PNG magic bytes', () {
      final bytes = [0x89, 0x50, 0x4E, 0x47, ...List.filled(20, 0)];
      expect(isRasterImageBytes(Uint8List.fromList(bytes)), isTrue);
    });

    test('accepts JPEG magic bytes', () {
      final bytes = [0xFF, 0xD8, 0xFF, ...List.filled(20, 0)];
      expect(isRasterImageBytes(Uint8List.fromList(bytes)), isTrue);
    });

    test('rejects HTML error pages', () {
      final bytes = '<!DOCTYPE html>'.codeUnits;
      expect(isRasterImageBytes(Uint8List.fromList(bytes)), isFalse);
    });

    test('rejects empty payload', () {
      expect(isRasterImageBytes(Uint8List(0)), isFalse);
    });
  });
}
