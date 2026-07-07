package com.beamngremoteplus.app

import android.graphics.Rect
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exclut certaines zones de l'écran (volant/pédales) des gestes système
 * Android (retour arrière, panneaux latéraux constructeur, etc.), qui
 * sinon volent le toucher pendant un appui prolongé près des bords/coins
 * de l'écran et interrompent l'affichage de l'app.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.beamngremoteplus.app/gesture_exclusion"
    private val logTag = "BeamRemotePlus"

    private fun toInt(value: Any?): Int {
        // Le codec standard Flutter peut encoder un entier en Int ou en Long
        // selon sa valeur : cast défensif via Number plutôt qu'un cast Int
        // strict, qui lèverait une ClassCastException silencieuse côté
        // plateforme si la valeur arrive en Long.
        return (value as? Number)?.toInt() ?: 0
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "setExclusionRects") {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            @Suppress("UNCHECKED_CAST")
                            val rectsData = call.arguments as List<Map<String, Any?>>
                            val rects = rectsData.map { r ->
                                Rect(toInt(r["left"]), toInt(r["top"]), toInt(r["right"]), toInt(r["bottom"]))
                            }
                            Log.i(logTag, "setSystemGestureExclusionRects: $rects")
                            window.decorView.systemGestureExclusionRects = rects
                        } else {
                            Log.i(logTag, "setSystemGestureExclusionRects skipped, SDK ${Build.VERSION.SDK_INT} < Q")
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(logTag, "setExclusionRects failed", e)
                        result.error("gesture_exclusion_error", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
