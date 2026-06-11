import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';

/// Returns true when [bytes] look like PNG, JPEG, or GIF (not HTML/JSON/etc.).
bool isRasterImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;

  // PNG
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }

  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }

  // GIF
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
    return true;
  }

  return false;
}

/// Fetches map tiles and validates bytes before decode.
///
/// Prevents Android `ImageDecoder` errors when a CDN returns HTML error pages
/// or other non-image payloads with HTTP 200.
class ValidatedNetworkTileProvider extends TileProvider {
  ValidatedNetworkTileProvider({
    super.headers,
    BaseClient? httpClient,
  }) : _httpClient = httpClient ?? RetryClient(Client());

  final BaseClient _httpClient;
  final _tilesInProgress = HashMap<TileCoordinates, Completer<void>>();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _ValidatedMapNetworkImageProvider(
        url: getTileUrl(coordinates, options),
        fallbackUrl: getTileFallbackUrl(coordinates, options),
        headers: headers,
        httpClient: _httpClient,
        startedLoading: () => _tilesInProgress[coordinates] = Completer(),
        finishedLoadingBytes: () {
          _tilesInProgress[coordinates]?.complete();
          _tilesInProgress.remove(coordinates);
        },
      );

  @override
  Future<void> dispose() async {
    if (_tilesInProgress.isNotEmpty) {
      await Future.wait(_tilesInProgress.values.map((c) => c.future));
    }
    _httpClient.close();
    super.dispose();
  }
}

@immutable
class _ValidatedMapNetworkImageProvider
    extends ImageProvider<_ValidatedMapNetworkImageProvider> {
  const _ValidatedMapNetworkImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.httpClient,
    required this.startedLoading,
    required this.finishedLoadingBytes,
  });

  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;
  final BaseClient httpClient;
  final void Function() startedLoading;
  final void Function() finishedLoadingBytes;

  @override
  ImageStreamCompleter loadImage(
    _ValidatedMapNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: url,
      );

  Future<Codec> _load(
    _ValidatedMapNetworkImageProvider key,
    ImageDecoderCallback decode, {
    bool useFallback = false,
  }) async {
    startedLoading();
    final targetUrl = useFallback ? fallbackUrl ?? '' : url;

    try {
      final bytes = await httpClient.readBytes(
        Uri.parse(targetUrl),
        headers: headers,
      );
      finishedLoadingBytes();

      if (!isRasterImageBytes(bytes)) {
        throw const FormatException('Response is not a raster image');
      }

      try {
        return await decode(await ImmutableBuffer.fromUint8List(bytes));
      } catch (_) {
        throw const FormatException('Image decode failed');
      }
    } on Exception catch (err, stack) {
      finishedLoadingBytes();
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));

      if (!useFallback && fallbackUrl != null) {
        return _load(key, decode, useFallback: true);
      }

      if (kDebugMode) {
        debugPrint('Map tile load failed ($targetUrl): $err');
        debugPrint('$stack');
      }

      return decode(
        await ImmutableBuffer.fromUint8List(TileProvider.transparentImage),
      );
    }
  }

  @override
  SynchronousFuture<_ValidatedMapNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _ValidatedMapNetworkImageProvider &&
          fallbackUrl == null &&
          url == other.url);

  @override
  int get hashCode => Object.hashAll([url, if (fallbackUrl != null) fallbackUrl]);
}
