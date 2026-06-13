import 'dart:math' as math;

import 'package:uzita/services/neshan_models.dart';

/// City/province hints parsed from free-text Persian addresses.
class AddressGeocodeHints {
  final String? city;
  final String? province;

  const AddressGeocodeHints({this.city, this.province});
}

/// Major Iranian cities for hint extraction from address text.
const _iranCities = <String, String>{
  'تهران': 'تهران',
  'اصفهان': 'اصفهان',
  'مشهد': 'خراسان رضوی',
  'شیراز': 'فارس',
  'تبریز': 'آذربایجان شرقی',
  'کرج': 'البرز',
  'اهواز': 'خوزستان',
  'قم': 'قم',
  'کرمانشاه': 'کرمانشاه',
  'رشت': 'گیلان',
  'یزد': 'یزد',
  'کرمان': 'کرمان',
  'اراک': 'مرکزی',
  'ارومیه': 'آذربایجان غربی',
  'زاهدان': 'سیستان و بلوچستان',
  'همدان': 'همدان',
  'قزوین': 'قزوین',
  'ساری': 'مازندران',
  'بندرعباس': 'هرمزگان',
  'بندر عباس': 'هرمزگان',
  'گرگان': 'گلستان',
  'سنندج': 'کردستان',
  'خرم‌آباد': 'لرستان',
  'خرم اباد': 'لرستان',
  'بوشهر': 'بوشهر',
  'ایلام': 'ایلام',
  'بیرجند': 'خراسان جنوبی',
  'شهرکرد': 'چهارمحال و بختیاری',
  'یاسوج': 'کهگیلویه و بویراحمد',
  'سمنان': 'سمنان',
};

AddressGeocodeHints extractGeocodeHints(String address) {
  final normalized = address
      .replaceAll('\u200c', ' ')
      .replaceAll('  ', ' ')
      .trim();

  for (final entry in _iranCities.entries) {
    if (normalized.contains(entry.key)) {
      return AddressGeocodeHints(city: entry.key, province: entry.value);
    }
  }

  return const AddressGeocodeHints();
}

/// Bias geocoding toward a region around [center] (Geocoding Plus `extent`).
NeshanGeocodingExtent geocodeExtentAround(
  NeshanLatLng center, {
  double radiusKm = 80,
}) {
  final latRad = center.latitude * math.pi / 180;
  final dLat = radiusKm / 111.0;
  final dLng = radiusKm / (111.0 * math.cos(latRad).abs().clamp(0.2, 1.0));

  return NeshanGeocodingExtent(
    southWest: NeshanLatLng(
      latitude: center.latitude - dLat,
      longitude: center.longitude - dLng,
    ),
    northEast: NeshanLatLng(
      latitude: center.latitude + dLat,
      longitude: center.longitude + dLng,
    ),
  );
}

bool isPlausibleIranCoordinate(NeshanLatLng location) {
  return location.latitude >= 24 &&
      location.latitude <= 40 &&
      location.longitude >= 44 &&
      location.longitude <= 64;
}
