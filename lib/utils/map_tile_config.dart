/// Map tile sources for [DriverNavigationMap].
///
/// Avoids `tile.openstreetmap.org` — often blocked or TLS-fails in Iran and on
/// Android when User-Agent is generic. Primary: MeMaps (Iranian CDN), fallback: Carto.
class MapTileConfig {
  const MapTileConfig._();

  static const String userAgentPackageName = 'com.example.uzita';

  /// MeMaps OSM — Iranian servers, no API key, works without international routing.
  static const String lightUrlTemplate = 'https://memaps.ir/hot/{z}/{x}/{y}.png';

  static const String darkUrlTemplate = 'https://memaps.ir/dark/{z}/{x}/{y}.png';

  /// Global CDN fallback when MeMaps is unreachable.
  static const String lightFallbackUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const String darkFallbackUrl =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';

  static const List<String> cartoSubdomains = ['a', 'b', 'c', 'd'];

  static String urlFor({required bool isDark}) =>
      isDark ? darkUrlTemplate : lightUrlTemplate;

  static String fallbackFor({required bool isDark}) =>
      isDark ? darkFallbackUrl : lightFallbackUrl;
}
