package com.beamremoteplus.app

import android.graphics.Rect
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.VibrationEffect
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

/**
 * Native helpers for the Flutter app:
 *  - gesture_exclusion: keeps Android edge/back gestures away from the pedals
 *  - network_info: finds the hotspot interface address (phone as access point)
 *    and the USB tethering ones
 *  - hardware_keys: captures the volume buttons while driving (horn / flash)
 *  - vibrator: variable-strength pulses for the road-feel haptics
 *  - sensors / gravity: gravity seen by the phone, from the gyroscope fused
 *    with the accelerometer (game rotation vector), for tilt steering
 *  - pov_video / pov_video_events: hardware player of the mod's point of
 *    view video (PovVideoPlayer)
 */
class MainActivity : FlutterActivity() {
    private val logTag = "BeamRemotePlus"
    private var hardwareKeysChannel: MethodChannel? = null
    private var volumeKeysCaptured = false
    private var gravityListener: SensorEventListener? = null
    private var povPlayer: PovVideoPlayer? = null
    private var povEvents: EventChannel.EventSink? = null

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

    // Interfaces of USB tethering (phone sharing its connection over the
    // cable): the PC is on their subnet, which the Wi-Fi broadcasts miss.
    private val usbTetheringPrefixes = listOf("usb", "rndis", "ncm")

    private fun findUsbTetheringAddresses(): List<Map<String, Any>> {
        val interfaces = try {
            Collections.list(NetworkInterface.getNetworkInterfaces())
        } catch (e: Exception) {
            Log.w(logTag, "getNetworkInterfaces failed", e)
            return emptyList()
        }
        val found = mutableListOf<Map<String, Any>>()
        for (iface in interfaces) {
            val name = iface.name.lowercase()
            if (usbTetheringPrefixes.none { name.startsWith(it) } || !iface.isUp) continue
            for (ifaceAddr in iface.interfaceAddresses) {
                val addr = ifaceAddr.address
                if (addr is Inet4Address && isPrivateIPv4(addr)) {
                    found.add(mapOf("address" to (addr.hostAddress ?: continue), "prefixLength" to ifaceAddr.networkPrefixLength.toInt()))
                }
            }
        }
        return found
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

        MethodChannel(messenger, "com.beamremoteplus.app/gesture_exclusion").setMethodCallHandler { call, result ->
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

        MethodChannel(messenger, "com.beamremoteplus.app/network_info").setMethodCallHandler { call, result ->
            when (call.method) {
                "getLikelyHotspotAddress" -> {
                    val found = findLikelyHotspotAddress()
                    result.success(found?.let { mapOf("address" to it.first, "prefixLength" to it.second) })
                }
                "getUsbTetheringAddresses" -> result.success(findUsbTetheringAddresses())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "com.beamremoteplus.app/vibrator").setMethodCallHandler { call, result ->
            if (call.method != "vibrate") return@setMethodCallHandler result.notImplemented()
            val ms = toInt(call.argument<Any>("ms")).toLong().coerceIn(1, 1000)
            val amplitude = toInt(call.argument<Any>("amplitude")).coerceIn(1, 255)
            val primitive = call.argument<String>("primitive")
            if (primitive == null || !vibratePrimitive(primitive, amplitude)) vibrate(ms, amplitude)
            result.success(null)
        }

        MethodChannel(messenger, "com.beamremoteplus.app/sensors").setMethodCallHandler { call, result ->
            if (call.method != "hasGameRotationVector") return@setMethodCallHandler result.notImplemented()
            result.success(gameRotationVector() != null)
        }

        EventChannel(messenger, "com.beamremoteplus.app/gravity").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) = startGravity(events)
            override fun onCancel(arguments: Any?) = stopGravity()
        })

        val povPlayer = PovVideoPlayer(flutterEngine.renderer) { event -> povEvents?.success(event) }
        this.povPlayer = povPlayer
        MethodChannel(messenger, "com.beamremoteplus.app/pov_video").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> try {
                    val host = call.argument<String>("host") ?: return@setMethodCallHandler result.error("bad_argument", "host", null)
                    result.success(povPlayer.start(host, toInt(call.argument<Any>("port")), toInt(call.argument<Any>("width")), toInt(call.argument<Any>("height"))))
                } catch (e: Exception) {
                    Log.e(logTag, "pov start failed", e)
                    result.error("pov_error", e.message, null)
                }
                "stop" -> {
                    povPlayer.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "com.beamremoteplus.app/pov_video_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                povEvents = events
            }
            override fun onCancel(arguments: Any?) {
                povEvents = null
            }
        })

        hardwareKeysChannel = MethodChannel(messenger, "com.beamremoteplus.app/hardware_keys").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "setVolumeKeysCaptured") return@setMethodCallHandler result.notImplemented()
                volumeKeysCaptured = call.arguments == true
                result.success(null)
            }
        }
    }

    override fun onDestroy() {
        povPlayer?.stop()
        super.onDestroy()
    }

    private fun sensorManager() = getSystemService(Context.SENSOR_SERVICE) as SensorManager

    // Fusion of the gyroscope and the accelerometer without the magnetometer:
    // smooth and quick relative rotations, unaffected by magnets.
    private fun gameRotationVector(): Sensor? = sensorManager().getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)

    // Streams the gravity vector in the phone frame (m/s², same axes as the
    // accelerometer), computed from the rotation: what the accelerometer
    // would read without the shakes of the hands.
    private fun startGravity(events: EventChannel.EventSink) {
        stopGravity()
        val sensor = gameRotationVector() ?: return events.error("unavailable", "no game rotation vector sensor", null)
        val rotation = FloatArray(9)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                val g = SensorManager.GRAVITY_EARTH
                events.success(listOf(rotation[6] * g, rotation[7] * g, rotation[8] * g))
            }
            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }
        gravityListener = listener
        sensorManager().registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    private fun stopGravity() {
        gravityListener?.let { sensorManager().unregisterListener(it) }
        gravityListener = null
    }

    private fun vibrator(): android.os.Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
    }

    // Short shaped vibrations of Android 11+ (tick, low tick, thud), when the
    // vibration motor supports them. Returns false otherwise: the caller then
    // plays the plain pulse, as on older phones.
    private fun vibratePrimitive(name: String, amplitude: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        val id = when (name) {
            "tick" -> VibrationEffect.Composition.PRIMITIVE_TICK
            "lowTick" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_LOW_TICK else return false
            "thud" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_THUD else return false
            else -> return false
        }
        val vibrator = vibrator()
        if (!vibrator.hasVibrator() || !vibrator.areAllPrimitivesSupported(id)) return false
        vibrator.vibrate(VibrationEffect.startComposition().addPrimitive(id, amplitude / 255f).compose())
        return true
    }

    @Suppress("DEPRECATION")
    private fun vibrate(ms: Long, amplitude: Int) {
        val vibrator = vibrator()
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val strength = if (vibrator.hasAmplitudeControl()) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
            vibrator.vibrate(VibrationEffect.createOneShot(ms, strength))
        } else {
            vibrator.vibrate(ms)
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
