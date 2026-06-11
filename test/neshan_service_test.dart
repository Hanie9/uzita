import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/services/neshan_service.dart';

void main() {
  const service = NeshanService();

  group('parseGeocodingBody', () {
    test('parses Geocoding Plus response with multiple candidates', () {
      const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.719934, "longitude": 51.340742},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "صادقیه",
      "unMatchedTerm": ""
    },
    {
      "location": {"latitude": 35.721686, "longitude": 51.343201},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "صادقیه",
      "unMatchedTerm": "رحیمی"
    }
  ]
}
''';

      final result = service.parseGeocodingBody(body, 'تهران ستارخان');
      expect(result.location.latitude, closeTo(35.719934, 0.0001));
      expect(result.city, 'تهران');
      expect(result.candidates.length, 2);
      expect(result.candidates.last.unMatchedTerm, 'رحیمی');
    });
  });

  group('parseRouteBody', () {
    test('parses routing v4 response with step modifier and polyline', () {
      const body = '''
{
  "routes": [
    {
      "overview_polyline": {"points": "kz{xEggtxHn@E"},
      "legs": [
        {
          "summary": "روانمهر - ولیعصر",
          "distance": {"value": 1820.0, "text": "۲ کیلومتر"},
          "duration": {"value": 487.0, "text": "۸ دقیقه"},
          "steps": [
            {
              "name": "میدان انقلاب اسلامی",
              "instruction": "در جهت جنوب در میدان انقلاب اسلامی قرار بگیرید",
              "bearing_after": 193,
              "type": "depart",
              "modifier": "left",
              "distance": {"value": 61.0, "text": "۷۵ متر"},
              "duration": {"value": 13.0, "text": "کمتر از ۱ دقیقه"},
              "polyline": "kz{xEggtxHHBRAPGPMJSDS",
              "start_location": [51.390755, 35.701021]
            },
            {
              "name": "ولیعصر",
              "instruction": "در مقصد قرار دارید",
              "bearing_after": 0,
              "type": "arrive",
              "distance": {"value": 0.0, "text": ""},
              "duration": {"value": 0.0, "text": ""},
              "polyline": "gx{xE{`wxH",
              "start_location": [51.405102, 35.700682]
            }
          ]
        }
      ]
    }
  ]
}
''';

      final route = service.parseRouteBody(body);
      expect(route.overviewPolyline, 'kz{xEggtxHn@E');
      expect(route.primaryLeg!.distanceMeters, 1820);
      expect(route.primaryLeg!.steps.length, 2);
      expect(route.primaryLeg!.steps.first.modifier, 'left');
      expect(route.primaryLeg!.steps.first.bearingAfter, 193);
      expect(route.primaryLeg!.steps.first.polyline, isNotEmpty);
      expect(route.primaryLeg!.steps.last.isArrival, isTrue);
    });
  });
}
