import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/services/neshan_models.dart';
import 'package:uzita/services/neshan_service.dart';
import 'package:uzita/utils/address_geocode_hints.dart';

void main() {
  const service = NeshanService();

  test('buildGeocodeSearchTerms puts full address before stripped query', () {
    final terms = buildGeocodeSearchTerms('تهران، میدان آزادی');
    expect(terms.first, 'تهران، میدان آزادی');
    expect(terms, contains('میدان آزادی'));
    expect(terms, contains('تهران، میدان آزادی'));
  });

  test('Search API picks Azadi square for POI address', () {
    const body = '''
{
  "count": 2,
  "items": [
    {
      "title": "میدان آزادی",
      "address": "تهران، میدان آزادی",
      "region": "تهران، استان تهران",
      "location": {"x": 51.352, "y": 35.700}
    },
    {
      "title": "آزادی",
      "address": "تهران، خیابان آزادی",
      "region": "تهران، استان تهران",
      "location": {"x": 51.340, "y": 35.710}
    }
  ]
}
''';
    final result = service.parseSearchBody(body, 'تهران، میدان آزادی');
    expect(result.title, 'میدان آزادی');
    expect(result.location.latitude, closeTo(35.700, 0.001));
    expect(isClearlyWrongGeocodingResult(result, 'تهران، میدان آزادی'), isFalse);
  });

  test('Geocoding Plus prefers first API-ranked candidate on tie', () {
    const address = 'تهران ستارخان';
    const candidates = [
      NeshanGeocodingCandidate(
        location: NeshanLatLng(latitude: 35.719934, longitude: 51.340742),
        city: 'تهران',
        neighbourhood: 'صادقیه',
        unMatchedTerm: '',
      ),
      NeshanGeocodingCandidate(
        location: NeshanLatLng(latitude: 35.721686, longitude: 51.343201),
        city: 'تهران',
        neighbourhood: 'صادقیه',
        unMatchedTerm: 'رحیمی',
      ),
    ];
    final best = pickBestGeocodingCandidate(candidates, address);
    expect(best.unMatchedTerm, '');
  });

  test('Geocoding Plus prefers exact POI over city centre', () {
    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.6892, "longitude": 51.3890},
      "city": "تهران",
      "unMatchedTerm": "میدان آزادی"
    },
    {
      "location": {"latitude": 35.700, "longitude": 51.352},
      "city": "تهران",
      "title": "میدان آزادی",
      "address": "تهران، میدان آزادی",
      "unMatchedTerm": ""
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, 'تهران، میدان آزادی');
    expect(result.location.latitude, closeTo(35.700, 0.01));
  });

  test('metro station search is accepted for metro address', () {
    const body = '''
{
  "count": 1,
  "items": [
    {
      "title": "ایستگاه مترو تجریش",
      "address": "تهران، تجریش",
      "region": "تهران، استان تهران",
      "location": {"x": 51.435, "y": 35.804}
    }
  ]
}
''';
    const address = 'تهران، ایستگاه مترو تجریش';
    final result = service.parseSearchBody(body, address);
    expect(result.title, contains('تجریش'));
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
  });

  test('street address with full API match is accepted', () {
    const address = 'تهران، خیابان ولیعصر';
    const result = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.761, longitude: 51.410),
      city: 'تهران',
      neighbourhood: 'جردن',
      unMatchedTerm: '',
    );
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
  });

  test('rejects unrelated search POI such as دانشگاه جنگ for ونک address', () {
    const address = 'تهران، میدان ونک';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.744, longitude: 51.195),
      city: 'تهران',
      title: 'دانشگاه جنگ',
      formattedAddress: 'تهران، دانشگاه علوم و فنون دفاعی',
    );
    expect(resultMatchesAddressTerms(wrong, address), isFalse);
    expect(isClearlyWrongGeocodingResult(wrong, address), isTrue);
    expect(isSpuriousDefaultSearchPoi(wrong, address), isTrue);
  });

  test('rejects defense university coordinates without POI metadata', () {
    const address = 'تهران، خیابان ولیعصر، پلاک ۱۲۳';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.7443, longitude: 51.1952),
      city: 'تهران',
      unMatchedTerm: '',
    );
    expect(isKnownNeshanFalsePositiveLocation(wrong, address), isTrue);
    expect(isHardRejectGeocodingResult(wrong, address), isTrue);
  });

  test('ستاد in street name does not accept defense university POI', () {
    const address = 'تهران، خیابان ستاد و ارتش';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.744, longitude: 51.195),
      city: 'تهران',
      title: 'دانشگاه فرماندهی و ستاد',
      formattedAddress: 'تهران، دانشگاه علوم و فنون فرماندهی و ستاد',
    );
    expect(isSpuriousDefaultSearchPoi(wrong, address), isTrue);
    expect(isHardRejectGeocodingResult(wrong, address), isTrue);
  });

  test('rejects دانشگاه فرماندهی و ستاد for unrelated street address', () {
    const address = 'تهران، خیابان ولیعصر';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.744, longitude: 51.195),
      city: 'تهران',
      title: 'دانشگاه فرماندهی و ستاد',
      formattedAddress: 'تهران، دانشگاه علوم و فنون فرماندهی و ستاد',
    );
    expect(isSpuriousDefaultSearchPoi(wrong, address), isTrue);
    expect(isClearlyWrongGeocodingResult(wrong, address), isTrue);
  });

  test('city name alone does not match unrelated POI title', () {
    const address = 'تهران';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.744, longitude: 51.195),
      city: 'تهران',
      title: 'دانشگاه فرماندهی و ستاد',
      formattedAddress: 'تهران، دانشگاه علوم و فنون',
    );
    expect(resultMatchesAddressTerms(wrong, address), isFalse);
  });

  test('rejects spurious POI outside city metro area', () {
    const address = 'تهران، میدان ونک';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.744, longitude: 51.195),
      city: 'تهران',
      title: 'دانشگاه فرماندهی و ستاد',
    );
    expect(isSpuriousDefaultSearchPoi(wrong, address), isTrue);
    expect(
      isGeocodeWithinBias(
        wrong,
        address: address,
        bias: const NeshanLatLng(latitude: 35.757, longitude: 51.410),
      ),
      isTrue,
    );
  });

  test('accepts Geocoding Plus full match inside city', () {
    const address = 'تهران، خیابان ولیعصر، نرسیده به پارک وی';
    const result = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.761, longitude: 51.410),
      city: 'تهران',
      neighbourhood: 'جردن',
      unMatchedTerm: '',
    );
    expect(isGeocodingPlusFullMatch(result), isTrue);
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
  });

  test('Ferdowsi metro POI resolves via Geocoding Plus extra terms', () {
    const address = 'تهران , ایستگاه مترو میدان فردوسی';
    expect(isPoiAddress(address), isTrue);
    expect(
      extractGeocodeQuery(address),
      'ایستگاه مترو میدان فردوسی',
    );

    final terms = buildGeocodeSearchTerms(address);
    expect(terms, contains('میدان فردوسی'));
    expect(terms, contains('تهران، میدان فردوسی'));

    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.6892, "longitude": 51.3890},
      "city": "تهران",
      "neighbourhood": "مرکز شهر",
      "unMatchedTerm": "ایستگاه مترو میدان فردوسی"
    },
    {
      "location": {"latitude": 35.6917, "longitude": 51.4193},
      "city": "تهران",
      "neighbourhood": "فردوسی",
      "unMatchedTerm": ""
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, address);
    expect(result.location.latitude, closeTo(35.6917, 0.001));
    expect(isHardRejectGeocodingResult(result, address), isFalse);
  });

  test('Bagheri metro POI resolves via Geocoding Plus extra terms', () {
    const address = 'تهران، ایستگاه مترو باقری';
    expect(isPoiAddress(address), isTrue);
    expect(
      extractGeocodeQuery(address),
      'ایستگاه مترو باقری',
    );

    final terms = buildGeocodeSearchTerms(address);
    expect(terms, contains('باقری'));
    expect(terms, contains('مترو باقری'));
    expect(terms, contains('تهران، باقری'));

    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.6892, "longitude": 51.3890},
      "city": "تهران",
      "neighbourhood": "مرکز شهر",
      "unMatchedTerm": "ایستگاه مترو باقری"
    },
    {
      "location": {"latitude": 35.7827, "longitude": 51.4884},
      "city": "تهران",
      "title": "ایستگاه مترو باقری",
      "neighbourhood": "باقری",
      "unMatchedTerm": ""
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, address);
    expect(result.location.latitude, closeTo(35.7827, 0.001));
    expect(result.title, contains('باقری'));
    expect(isHardRejectGeocodingResult(result, address), isFalse);
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
  });

  test('rejects city-centre Plus snap for Bagheri metro POI', () {
    const address = 'تهران، ایستگاه مترو باقری';
    const cityCentre = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.6892, longitude: 51.3890),
      city: 'تهران',
      neighbourhood: 'مرکز شهر',
      unMatchedTerm: '',
    );
    expect(isClearlyWrongGeocodingResult(cityCentre, address), isTrue);
    expect(isCityCentreGeocodingSnap(cityCentre, address), isTrue);
  });

  test('titleless Plus full match does not relate metro POI without overlap', () {
    const address = 'تهران، ایستگاه مترو میدان فردوسی';
    const wrong = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.750, longitude: 51.350),
      city: 'تهران',
      neighbourhood: 'مرکز شهر',
      unMatchedTerm: '',
    );
    expect(resultMatchesAddressTerms(wrong, address), isFalse);
    // Away from city-centre cluster — may be accepted when Search is unavailable.
    expect(isClearlyWrongGeocodingResult(wrong, address), isFalse);
  });

  test('rejects biased Geocoding Plus city-centre cluster for Ferdowsi metro', () {
    const address = 'تهران، ایستگاه مترو میدان فردوسی';
    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.690615, "longitude": 51.388942},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "حر",
      "unMatchedTerm": ""
    },
    {
      "location": {"latitude": 35.690829, "longitude": 51.388497},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "حر",
      "unMatchedTerm": "میدان فردوسی"
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, address);
    expect(isCityCentreGeocodingSnap(result, address), isTrue);
    expect(isClearlyWrongGeocodingResult(result, address), isTrue);
  });

  test('accepts unbiased Geocoding Plus result for Ferdowsi metro', () {
    const address = 'تهران، ایستگاه مترو میدان فردوسی';
    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.7015, "longitude": 51.4195},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "فردوسی",
      "unMatchedTerm": ""
    },
    {
      "location": {"latitude": 35.6991, "longitude": 51.4372},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "شمیران",
      "unMatchedTerm": "میدان فردوسی"
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, address);
    expect(result.location.latitude, closeTo(35.7015, 0.001));
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
    expect(isCityCentreGeocodingSnap(result, address), isFalse);
  });

  test('accepts unbiased Geocoding Plus result for Bagheri metro', () {
    const address = 'تهران ، ایستگاه مترو باقری';
    const body = '''
{
  "items": [
    {
      "location": {"latitude": 35.7327, "longitude": 51.5164},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "دردشت",
      "unMatchedTerm": ""
    },
    {
      "location": {"latitude": 35.7332, "longitude": 51.5168},
      "province": "تهران",
      "city": "تهران",
      "neighbourhood": "نارمک",
      "unMatchedTerm": ""
    }
  ]
}
''';
    final result = service.parseGeocodingBody(body, address);
    expect(result.location.latitude, closeTo(35.7327, 0.001));
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
    expect(isCityCentreGeocodingSnap(result, address), isFalse);
  });

  test('accepts Geocoding Plus partial match for street address', () {
    const address = 'تهران، خیابان ستارخان، پلاک ۱۲';
    const result = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.719, longitude: 51.341),
      city: 'تهران',
      neighbourhood: 'صادقیه',
      unMatchedTerm: 'پلاک ۱۲',
    );
    expect(isClearlyWrongGeocodingResult(result, address), isFalse);
  });

  test('accepts nearest Geocoding Plus result even without term overlap', () {
    const address = 'تهران، خیابان نامشخص ۹۹';
    const approximate = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.721, longitude: 51.334),
      city: 'تهران',
      neighbourhood: 'ستارخان',
      unMatchedTerm: 'نامشخص ۹۹',
    );
    expect(isHardRejectGeocodingResult(approximate, address), isFalse);
  });

  test('rejects city-centre Plus snap for Ferdowsi metro POI', () {
    const address = 'تهران , ایستگاه مترو میدان فردوسی';
    const cityCentre = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.6892, longitude: 51.3890),
      city: 'تهران',
      neighbourhood: 'مرکز شهر',
      unMatchedTerm: '',
    );
    expect(isGeocodingPlusFullMatch(cityCentre), isTrue);
    expect(isHardRejectGeocodingResult(cityCentre, address), isFalse);
    expect(isClearlyWrongGeocodingResult(cityCentre, address), isTrue);
    expect(isCityCentreGeocodingSnap(cityCentre, address), isTrue);
  });

  test('rejects city-centre snap for street address without term overlap', () {
    const address = 'تهران، خیابان ولیعصر، پلاک ۱۲۳';
    const cityCentre = NeshanGeocodingResult(
      location: NeshanLatLng(latitude: 35.6892, longitude: 51.3890),
      city: 'تهران',
      neighbourhood: 'مرکز شهر',
      unMatchedTerm: '',
    );
    expect(isClearlyWrongGeocodingResult(cityCentre, address), isTrue);
    expect(isCityCentreGeocodingSnap(cityCentre, address), isTrue);
  });

  test('cargo geocode params omit extent bias for POI addresses', () {
    const hints = AddressGeocodeHints(city: 'تهران', province: 'تهران');
    final poiParams = buildCargoGeocodeParams(
      address: 'تهران، ایستگاه مترو میدان فردوسی',
      hints: hints,
    );
    expect(poiParams.city, 'تهران');
    expect(poiParams.searchCenter, isNull);
    expect(poiParams.searchExtent, isNull);

    final streetParams = buildCargoGeocodeParams(
      address: 'تهران، خیابان آزادی',
      hints: hints,
    );
    expect(streetParams.searchCenter?.latitude, closeTo(35.6892, 0.001));
    expect(streetParams.searchExtent, isNotNull);
  });

  test('extractPostalCodeGush returns first five digits', () {
    expect(
      extractPostalCodeGush('تهران، خیابان آزادی، کد پستی 1234567890'),
      '12345',
    );
  });
}
