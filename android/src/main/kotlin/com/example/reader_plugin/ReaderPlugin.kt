package com.example.reader_plugin

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

/** ReaderPlugin */
class ReaderPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var context: Context
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private var receiver: BroadcastReceiver? = null

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "reader_plugin/methods")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(binding.binaryMessenger, "reader_plugin/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when (call.method) {
      "startScan" -> {
        startScan()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun startScan() {
    try {
      val intent = Intent("com.system.key_f2")
      context.sendBroadcast(intent)
      Log.d("ReaderPlugin", "Broadcast sent: com.system.key_f2")
      Toast.makeText(context, "Escaneo iniciado...", Toast.LENGTH_SHORT).show()
    } catch (e: Exception) {
      Log.e("ReaderPlugin", "Error al iniciar escaneo: ${e.message}")
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    registerReceiver()
  }

  override fun onCancel(arguments: Any?) {
    unregisterReceiver()
    eventSink = null
  }

  private fun registerReceiver() {
    if (receiver != null) return

    val filter = IntentFilter("com.android.serial.BARCODEPORT_RECEIVEDDATA_ACTION")
    receiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        val data = intent?.getStringExtra("DATA") ?: return
        Log.d("ReaderPlugin", "Scan data received: $data")
        Handler(Looper.getMainLooper()).post {
          eventSink?.success(data)
        }
      }
    }
    context.registerReceiver(receiver, filter)
    Log.d("ReaderPlugin", "BroadcastReceiver registrado")
  }

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

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    unregisterReceiver()
  }
}

