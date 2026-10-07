package com.beamngremoteplus.app

import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

/**
 * Native helpers for the Flutter app:
 *  - gesture_exclusion: keeps Android edge/back gestures away from the pedals
 *  - network_info: finds the hotspot interface address (phone as access point)
 *  - hardware_keys: captures the volume buttons while driving (horn / flash)
 */
class MainActivity : FlutterActivity() {
    private val logTag = "BeamRemotePlus"
    private var hardwareKeysChannel: MethodChannel? = null
    private var volumeKeysCaptured = false

    // Interfaces that are never the local Wi-Fi access point (mobile data,
    // USB tethering, loopback): skipping them avoids picking the SIM address.
    private val excludedInterfacePrefixes = listOf("rmnet", "ccmni", "pdp", "usb", "rndis", "lo")

    // The standard codec may encode an integer as Int or Long.
    private fun toInt(value: Any?): Int = (value as? Number)?.toInt() ?: 0

    private fun isPrivateIPv4(addr: Inet4Address): Boolean {
        val b = addr.address
        val a0 = b[0].toInt() and 0xFF
        val a1 = b[1].toInt() and 0xFF
        return a0 == 10 || (a0 == 172 && a1 in 16..31) || (a0 == 192 && a1 == 168)
    }

    // In hotspot mode WifiManager only knows the station connection, which
    // does not exist; the address is still on a network interface, whose name
    // depends on the vendor (ap0, wlan0, swlan0...), hence the heuristic.
    private fun findLikelyHotspotAddress(): Pair<String, Int>? {
        val interfaces = try {
            Collections.list(NetworkInterface.getNetworkInterfaces())
        } catch (e: Exception) {
            Log.w(logTag, "getNetworkInterfaces failed", e)
            return null
        }
        val candidates = mutableListOf<Triple<String, Inet4Address, Int>>()
        for (iface in interfaces) {
            val name = iface.name.lowercase()
            if (excludedInterfacePrefixes.any { name.startsWith(it) }) continue
            if (!iface.isUp || iface.isLoopback) continue
            for (ifaceAddr in iface.interfaceAddresses) {
                val addr = ifaceAddr.address
                if (addr is Inet4Address && !addr.isLoopbackAddress && isPrivateIPv4(addr)) {
                    candidates.add(Triple(name, addr, ifaceAddr.networkPrefixLength.toInt()))
                }
            }
        }
        if (candidates.isEmpty()) return null
        val preferred = candidates.firstOrNull {
            it.first.startsWith("ap") || it.first.startsWith("wlan") || it.first.startsWith("swlan")
        } ?: candidates.first()
        return Pair(preferred.second.hostAddress ?: return null, preferred.third)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.beamngremoteplus.app/gesture_exclusion").setMethodCallHandler { call, result ->
            if (call.method != "setExclusionRects") return@setMethodCallHandler result.notImplemented()
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    @Suppress("UNCHECKED_CAST")
                    val rects = (call.arguments as List<Map<String, Any?>>).map { r ->
                        Rect(toInt(r["left"]), toInt(r["top"]), toInt(r["right"]), toInt(r["bottom"]))
                    }
                    window.decorView.systemGestureExclusionRects = rects
                }
                result.success(null)
            } catch (e: Exception) {
                Log.e(logTag, "setExclusionRects failed", e)
                result.error("gesture_exclusion_error", e.message, null)
            }
        }

        MethodChannel(messenger, "com.beamngremoteplus.app/network_info").setMethodCallHandler { call, result ->
            if (call.method != "getLikelyHotspotAddress") return@setMethodCallHandler result.notImplemented()
            val found = findLikelyHotspotAddress()
            result.success(found?.let { mapOf("address" to it.first, "prefixLength" to it.second) })
        }

        hardwareKeysChannel = MethodChannel(messenger, "com.beamngremoteplus.app/hardware_keys").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "setVolumeKeysCaptured") return@setMethodCallHandler result.notImplemented()
                volumeKeysCaptured = call.arguments == true
                result.success(null)
            }
        }
    }

    // Consumes the volume buttons while captured (the media volume does not
    // change) and reports one press and one release per physical press;
    // auto-repeat events of a held button are swallowed.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val key = when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> "up"
            KeyEvent.KEYCODE_VOLUME_DOWN -> "down"
            else -> null
        }
        val channel = hardwareKeysChannel
        if (key == null || !volumeKeysCaptured || channel == null) return super.dispatchKeyEvent(event)
        when (event.action) {
            KeyEvent.ACTION_DOWN -> if (event.repeatCount == 0) {
                channel.invokeMethod("onVolumeKey", mapOf("key" to key, "pressed" to true))
            }
            KeyEvent.ACTION_UP -> channel.invokeMethod("onVolumeKey", mapOf("key" to key, "pressed" to false))
        }
        return true
    }
}
