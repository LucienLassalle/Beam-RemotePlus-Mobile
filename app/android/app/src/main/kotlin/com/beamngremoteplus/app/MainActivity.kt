package com.beamngremoteplus.app

import android.graphics.Rect
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.Collections

/**
 * Exclut certaines zones de l'écran (volant/pédales) des gestes système
 * Android (retour arrière, panneaux latéraux constructeur, etc.), qui
 * sinon volent le toucher pendant un appui prolongé près des bords/coins
 * de l'écran et interrompent l'affichage de l'app.
 */
class MainActivity : FlutterActivity() {
    private val gestureChannelName = "com.beamngremoteplus.app/gesture_exclusion"
    private val networkChannelName = "com.beamngremoteplus.app/network_info"
    private val logTag = "BeamRemotePlus"

    // Préfixes d'interface à ignorer explicitement : elles ne sont jamais
    // le point d'accès WiFi local, seulement la donnée mobile ou un
    // partage de connexion USB. Évite de confondre l'IP de la carte SIM
    // avec celle du hotspot WiFi.
    private val excludedInterfacePrefixes = listOf("rmnet", "ccmni", "pdp", "usb", "rndis", "lo")

    private fun toInt(value: Any?): Int {
        // Le codec standard Flutter peut encoder un entier en Int ou en Long
        // selon sa valeur : cast défensif via Number plutôt qu'un cast Int
        // strict, qui lèverait une ClassCastException silencieuse côté
        // plateforme si la valeur arrive en Long.
        return (value as? Number)?.toInt() ?: 0
    }

    private fun isPrivateIPv4(addr: Inet4Address): Boolean {
        val b = addr.address
        val a0 = b[0].toInt() and 0xFF
        val a1 = b[1].toInt() and 0xFF
        return a0 == 10 || (a0 == 172 && a1 in 16..31) || (a0 == 192 && a1 == 168)
    }

    // NetworkInfo().getWifiIP() (network_info_plus, côté Dart) renvoie null
    // quand le téléphone fait point d'accès mobile : WifiManager expose
    // l'IP de connexion STA (station), qui n'existe pas en mode AP. Cette
    // info existe pourtant bien au niveau interface réseau (celle que le
    // hotspot attribue à lui-même comme passerelle), juste pas via cette
    // API. On la retrouve en énumérant les interfaces système directement
    // — technique standard côté Android pour cette limitation connue, le
    // nom de l'interface AP variant selon le constructeur (ap0, wlan0,
    // swlan0...), d'où l'heuristique par plage d'adresse privée plutôt que
    // par nom exact.
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
        Log.i(logTag, "findLikelyHotspotAddress candidates: " + candidates.map { "${it.first}=${it.second.hostAddress}/${it.third}" })
        if (candidates.isEmpty()) return null

        // Priorité aux noms d'interface habituellement utilisés pour l'AP
        // WiFi local ; à défaut, on prend la première adresse privée trouvée
        // (mieux que rien, et la découverte réseau applique de toute façon
        // 255.255.255.255 en complément côté Dart).
        val preferred = candidates.firstOrNull {
            it.first.startsWith("ap") || it.first.startsWith("wlan") || it.first.startsWith("swlan")
        } ?: candidates.first()

        Log.i(logTag, "findLikelyHotspotAddress chose: ${preferred.first}=${preferred.second.hostAddress}/${preferred.third}")
        return Pair(preferred.second.hostAddress ?: return null, preferred.third)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, gestureChannelName)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, networkChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getLikelyHotspotAddress") {
                    val found = findLikelyHotspotAddress()
                    if (found == null) {
                        result.success(null)
                    } else {
                        result.success(mapOf("address" to found.first, "prefixLength" to found.second))
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
