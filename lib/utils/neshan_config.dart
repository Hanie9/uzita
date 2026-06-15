import 'package:uzita/generated/neshan_secrets.g.dart';

/// Neshan service key (`service.xxx` from panel → سرویس‌ها).
/// On Android SDK routing this key is passed to [NeshanDirection]; map auth uses
/// [neshan.license] only (no separate Android API key in panel).
String get neshanApiKey {
  const fromDefine = String.fromEnvironment('NESHAN_API_KEY');
  if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
  return embeddedNeshanApiKey.trim();
}

/// Neshan **Android** key (panel → ANDROID tab, package + SHA-1).
/// Use for direct REST calls from the APK.
String get neshanAndroidApiKey {
  const fromDefine = String.fromEnvironment('NESHAN_ANDROID_KEY');
  if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
  return embeddedNeshanAndroidKey.trim();
}

String get neshanMapKey {
  const fromDefine = String.fromEnvironment('NESHAN_MAP_KEY');
  if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
  return embeddedNeshanMapKey.trim();
}

/// Geocoding Plus — matches «تبدیل آدرس به نقطه پلاس» in panel.
const String neshanGeocodingBaseUrl = 'https://api.neshan.org/geocoding/v1/plus';

/// Routing with live traffic — matches «مسیریابی با ترافیک» in panel.
const String neshanDirectionBaseUrl = 'https://api.neshan.org/v4/direction';

/// Routing without live traffic — baseline for segment traffic coloring.
const String neshanNoTrafficDirectionBaseUrl =
    'https://api.neshan.org/v4/direction/no-traffic';

/// Typical traffic pattern routing — fallback baseline when no-traffic fails.
const String neshanTypicalDirectionBaseUrl =
    'https://api.neshan.org/v4/direction/typical';

/// Static arc map — matches «نقشه استاتیک منحنی‌دار» in panel.
const String neshanStaticArcUrl = 'https://api.neshan.org/v4/static/arc';

bool get hasNeshanApiKey => neshanApiKey.trim().isNotEmpty;

bool get hasNeshanAndroidKey => neshanAndroidApiKey.trim().isNotEmpty;

/// API key for routing REST/SDK calls (service key when no Android key exists).
String get neshanDirectApiKey {
  if (hasNeshanAndroidKey) return neshanAndroidApiKey;
  return neshanApiKey;
}

bool get hasDirectNeshanKey => neshanDirectApiKey.trim().isNotEmpty;

String get effectiveNeshanMapKey => neshanMapKey.trim();

/// Static arc map works with the same service key.
bool get canShowNeshanStaticMap =>
    hasNeshanApiKey || hasNeshanAndroidKey || hasDirectNeshanKey;
