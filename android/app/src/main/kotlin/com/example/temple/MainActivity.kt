package com.example.temple

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Vibración del temporizador de Intervalos (lib/device/interval_cues.dart).
        // A diferencia de HapticFeedback, vibra aunque la respuesta táctil del
        // sistema esté desactivada.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "temple/vibrate")
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    val pattern = call.argument<List<Number>>("pattern")
                        ?.map { it.toLong() }
                        ?.toLongArray()
                    if (pattern != null && pattern.isNotEmpty()) vibrate(pattern)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun vibrator(): Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    /** [pattern]: pausa, vibración, pausa, vibración… en milisegundos. */
    private fun vibrate(pattern: LongArray) {
        val v = vibrator()
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(pattern, -1)
        }
    }
}
