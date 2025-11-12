import 'dart:async';                 // Para manejar flujos asíncronos (Stream, Future)
import 'package:flutter/services.dart'; // Para comunicación con el código nativo (MethodChannel y EventChannel)

/// Clase principal del plugin Flutter
/// 
/// Esta clase sirve como interfaz entre el código Flutter y el código nativo de Android.
/// Usa canales de comunicación para:
/// - Enviar comandos (MethodChannel)
/// - Recibir datos en tiempo real (EventChannel)
class ReaderPlugin {
  // Canal para enviar métodos desde Flutter al código nativo de Android.
  // En este caso se usa para invocar "startScan".
  static const MethodChannel _methodChannel =
      MethodChannel('reader_plugin/methods');

  // Canal de eventos para recibir datos desde Android hacia Flutter.
  // Se usa para escuchar las lecturas del escáner.
  static const EventChannel _eventChannel =
      EventChannel('reader_plugin/events');

  // Stream interno que emitirá los datos recibidos del escáner.
  static Stream<String>? _scanStream;

  // --------------------------------------------------------------------------
  //  Método que ordena iniciar un escaneo en el dispositivo
  // --------------------------------------------------------------------------
  /// Envía la señal al código nativo para iniciar el escaneo.
  /// 
  /// Internamente, llama al método "startScan" definido en el plugin Android.
  /// Esto dispara el intent "com.system.key_f2" en el sistema, activando el lector físico.
  static Future<void> startScan() async {
    await _methodChannel.invokeMethod('startScan');
  }

  // --------------------------------------------------------------------------
  // Stream que escucha los resultados del lector en tiempo real
  // --------------------------------------------------------------------------
  /// Devuelve un flujo (Stream) con los datos recibidos del lector.
  ///
  /// Este flujo está conectado al EventChannel, que emite cada vez que el plugin
  /// Android recibe un broadcast con un dato leído (por ejemplo, una cédula escaneada).
  static Stream<String> get onScanData {
    // Si el stream aún no existe, se crea
    _scanStream ??= _eventChannel
        // Se suscribe al canal de eventos nativo
        .receiveBroadcastStream()
        // Convierte cualquier tipo de evento recibido a String
        .map((event) => event.toString());

    // Devuelve el stream que emitirá los datos del escáner
    return _scanStream!;
  }
}

