import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/utils/technician_task_utils.dart';

void main() {
  test('technicianIdCountMapFromList reads id/count objects', () {
    final map = technicianIdCountMapFromList(<Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'count': 3},
      <String, dynamic>{'id': 2, 'count': 1},
    ]);
    expect(map, <int, int>{1: 3, 2: 1});
  });

  test('technicianIdCountMapFromList falls back for plain ids', () {
    final map = technicianIdCountMapFromList(<int>[5, 7]);
    expect(map, <int, int>{5: 1, 7: 1});
  });

  test('technicianIdCountMapToApiList sorts by id', () {
    final list = technicianIdCountMapToApiList(<int, int>{7: 2, 1: 3});
    expect(list, <Map<String, int>>[
      <String, int>{'id': 1, 'count': 3},
      <String, int>{'id': 7, 'count': 2},
    ]);
  });

  test('technicianItemCountSuffix only shows for count > 1', () {
    expect(technicianItemCountSuffix(1), '');
    expect(technicianItemCountSuffix(3), ' ×3');
  });
}
