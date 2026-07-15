import 'package:flutter/services.dart';

/// Android: MethodChannel + EventChannel for native Neshan MapView.
class NeshanMapBindings {
  NeshanMapBindings._();

  static const MethodChannel channel =
      MethodChannel('com.example.uzita/neshan_map');
  static Stream<dynamic> get events =>
      eventsChannel.receiveBroadcastStream();

  static const EventChannel eventsChannel =
      EventChannel('com.example.uzita/neshan_map_events');

  static Future<void> invokeMethod(
    String method,
    Map<String, dynamic> arguments,
  ) {
    return channel.invokeMethod<void>(method, arguments);
  }
}
