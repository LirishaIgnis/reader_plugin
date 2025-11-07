import 'dart:async';
import 'package:flutter/services.dart';

class ReaderPlugin {
  static const MethodChannel _methodChannel =
      MethodChannel('reader_plugin/methods');
  static const EventChannel _eventChannel =
      EventChannel('reader_plugin/events');

  static Stream<String>? _scanStream;

  /// Envía la señal para iniciar un escaneo
  static Future<void> startScan() async {
    await _methodChannel.invokeMethod('startScan');
  }

  /// Devuelve un stream con los resultados del lector
  static Stream<String> get onScanData {
    _scanStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
    return _scanStream!;
  }
}
