package com.example.reader_plugin

// Importaciones necesarias para manejar contexto, logs, mensajes y canales de comunicación con Flutter
import android.content.*
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** 
 * ReaderPlugin
 * 
 * Este plugin conecta el entorno nativo de Android con Flutter.
 * Se encarga de iniciar el escáner de códigos y de recibir los datos escaneados
 * mediante broadcast intents del sistema.
 */
class ReaderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  // Contexto de la aplicación, necesario para acceder a recursos del sistema Android
  private lateinit var context: Context

  // Canal para invocar métodos desde Flutter hacia Android
  private lateinit var methodChannel: MethodChannel

  // Canal para enviar eventos desde Android hacia Flutter (datos en tiempo real)
  private lateinit var eventChannel: EventChannel

  // Objeto que envía los datos escaneados al lado de Flutter
  private var eventSink: EventChannel.EventSink? = null

  // Receptor que escucha los broadcasts del sistema (cuando se recibe un escaneo)
  private var receiver: BroadcastReceiver? = null

  // --------------------------------------------------------------------------
  // Se ejecuta cuando el plugin se conecta con el motor de Flutter
  // --------------------------------------------------------------------------
  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    // Obtiene el contexto de la aplicación
    context = binding.applicationContext

    // Crea el canal de métodos para recibir llamadas desde Flutter
    methodChannel = MethodChannel(binding.binaryMessenger, "reader_plugin/methods")
    methodChannel.setMethodCallHandler(this)

    // Crea el canal de eventos para enviar datos hacia Flutter
    eventChannel = EventChannel(binding.binaryMessenger, "reader_plugin/events")
    eventChannel.setStreamHandler(this)
  }

  // --------------------------------------------------------------------------
  // Manejo de llamadas de métodos desde Flutter
  // --------------------------------------------------------------------------
  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      // Si Flutter invoca "startScan", se ejecuta el método que inicia el escaneo
      "startScan" -> {
        startScan()
        result.success(null) // Devuelve éxito sin datos
      }
      // Si se llama un método no implementado, se devuelve un error
      else -> result.notImplemented()
    }
  }

  // --------------------------------------------------------------------------
  //  Método que envía un broadcast al sistema para iniciar el escáner
  // --------------------------------------------------------------------------
  private fun startScan() {
    try {
      // Envía un intent al sistema con la acción "com.system.key_f2"
      // que generalmente dispara el lector físico de códigos de barras
      val intent = Intent("com.system.key_f2")
      context.sendBroadcast(intent)

      // Log de depuración
      Log.d("ReaderPlugin", "Broadcast sent: com.system.key_f2")

      // Mensaje visual corto al usuario indicando que se inició el escaneo
      Toast.makeText(context, "Escaneo iniciado...", Toast.LENGTH_SHORT).show()
    } catch (e: Exception) {
      // Si ocurre un error, se muestra en el log
      Log.e("ReaderPlugin", "Error al iniciar escaneo: ${e.message}")
    }
  }

  // --------------------------------------------------------------------------
  // Se ejecuta cuando Flutter empieza a escuchar eventos del plugin
  // --------------------------------------------------------------------------
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    registerReceiver() // Registra el receptor para recibir los datos del escáner
  }

  // --------------------------------------------------------------------------
  // Se ejecuta cuando Flutter deja de escuchar eventos
  // --------------------------------------------------------------------------
  override fun onCancel(arguments: Any?) {
    unregisterReceiver() // Se desregistra el receptor
    eventSink = null
  }

  // --------------------------------------------------------------------------
  // Registra un BroadcastReceiver para escuchar los datos escaneados
  // --------------------------------------------------------------------------
  private fun registerReceiver() {
    // Si ya hay un receptor registrado, no hace nada
    if (receiver != null) return

    // Filtro para escuchar los broadcasts con acción específica del escáner
    val filter = IntentFilter("com.android.serial.BARCODEPORT_RECEIVEDDATA_ACTION")

    // Se crea el receptor anónimo
    receiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        // Obtiene la cadena de datos escaneada (extra "DATA")
        val data = intent?.getStringExtra("DATA") ?: return

        // Log de depuración
        Log.d("ReaderPlugin", "Scan data received: $data")

        // Envía los datos al hilo principal y los pasa al eventSink (Flutter)
        Handler(Looper.getMainLooper()).post {
          eventSink?.success(data)
        }
      }
    }

    // Registra el receptor en el contexto de la app
    context.registerReceiver(receiver, filter)
    Log.d("ReaderPlugin", "BroadcastReceiver registrado")
  }

  // --------------------------------------------------------------------------
  // Desregistra el BroadcastReceiver cuando ya no se necesita
  // --------------------------------------------------------------------------
  private fun unregisterReceiver() {
    try {
      if (receiver != null) {
        context.unregisterReceiver(receiver)
        receiver = null
        Log.d("ReaderPlugin", "BroadcastReceiver desregistrado")
      }
    } catch (e: Exception) {
      Log.e("ReaderPlugin", "Error al desregistrar receiver: ${e.message}")
    }
  }

  // --------------------------------------------------------------------------
  //  Se ejecuta cuando el plugin se desconecta del motor de Flutter
  // --------------------------------------------------------------------------
  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    // Limpia los handlers y canales
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    unregisterReceiver() // Libera el receptor si aún está activo
  }
}
