package com.beamremoteplus.app

import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.SocketTimeoutException

/**
 * Player of the point of view video of the mod: H.264 in MPEG-TS over UDP
 * (see the mod's PROTOCOL.md, section 6), decoded by the phone's hardware
 * decoder straight into a Flutter texture, for the lowest latency: no
 * buffering, every frame is shown as soon as it is decoded.
 *
 * One thread receives, demuxes and decodes. Until a keyframe arrives, and
 * after a lost packet, frames are skipped: the picture freezes for a moment
 * instead of smearing.
 *
 * Events (main thread): {"type": "size", "width", "height"} once the
 * decoder knows the picture, {"type": "error", "message"} when the decoder
 * fails.
 */
class PovVideoPlayer(
    private val textures: TextureRegistry,
    private val onEvent: (Map<String, Any>) -> Unit,
) {
    private val logTag = "BeamRemotePlus"
    private val main = Handler(Looper.getMainLooper())
    private val lock = Object()
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var thread: Thread? = null
    @Volatile private var running = false
    private var socket: DatagramSocket? = null

    // Owned by the receiving thread, guarded by [lock] against the surface callbacks.
    private var decoder: MediaCodec? = null
    private var surface: Surface? = null
    private var surfaceChanged = false
    private var waitingKeyframe = true
    private var width = 0
    private var height = 0

    /** Starts listening on [port] for the video of [host]; returns the texture id. */
    fun start(host: String, port: Int, width: Int, height: Int): Long {
        stop()
        this.width = width
        this.height = height
        val producer = textures.createSurfaceProducer()
        producer.setSize(width, height)
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                synchronized(lock) {
                    surface = producer.surface
                    surfaceChanged = true
                }
            }

            override fun onSurfaceCleanup() {
                synchronized(lock) {
                    releaseDecoder()
                    surface = null
                }
            }
        })
        this.producer = producer
        surface = producer.surface
        surfaceChanged = true
        val socket = DatagramSocket(null).apply {
            reuseAddress = true
            receiveBufferSize = 4 * 1024 * 1024
            soTimeout = 100
            bind(InetSocketAddress(port))
        }
        this.socket = socket
        running = true
        thread = Thread({ receive(socket, host) }, "pov-video").apply { start() }
        return producer.id()
    }

    fun stop() {
        running = false
        socket?.close()
        thread?.join(500)
        thread = null
        socket = null
        synchronized(lock) {
            releaseDecoder()
            surface = null
        }
        producer?.release()
        producer = null
    }

    private fun receive(socket: DatagramSocket, host: String) {
        val buffer = ByteArray(65536)
        val packet = DatagramPacket(buffer, buffer.size)
        val demuxer = TsDemuxer { au, ptsUs, corrupt -> decode(au, ptsUs, corrupt) }
        while (running) {
            try {
                socket.receive(packet)
            } catch (e: SocketTimeoutException) {
                drain()
                continue
            } catch (e: Exception) {
                if (running) Log.w(logTag, "pov: receive failed", e)
                break
            }
            // Only the paired PC.
            if (packet.address?.hostAddress != host) continue
            demuxer.feed(buffer, packet.length)
            drain()
        }
    }

    private fun decode(au: ByteArray, ptsUs: Long, corrupt: Boolean) {
        synchronized(lock) {
            if (corrupt) {
                waitingKeyframe = true
                return
            }
            if (waitingKeyframe) {
                if (!TsDemuxer.isKeyframe(au)) return
                waitingKeyframe = false
            }
            val codec = codec() ?: return
            try {
                val index = codec.dequeueInputBuffer(5_000)
                if (index < 0) {
                    waitingKeyframe = true // decoder behind: drop, start again on a keyframe
                    return
                }
                val input = codec.getInputBuffer(index) ?: return
                input.clear()
                input.put(au, 0, minOf(au.size, input.capacity()))
                codec.queueInputBuffer(index, 0, minOf(au.size, input.capacity()), ptsUs, 0)
            } catch (e: Exception) {
                fail("decode", e)
            }
        }
    }

    // The decoder, created on the current surface (again after it changed).
    private fun codec(): MediaCodec? {
        if (surfaceChanged) {
            releaseDecoder()
            surfaceChanged = false
        }
        decoder?.let { return it }
        val target = surface ?: return null
        return try {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
                setInteger(MediaFormat.KEY_PRIORITY, 0) // real time
            }
            MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
                configure(format, target, null, 0)
                start()
            }.also { decoder = it }
        } catch (e: Exception) {
            fail("create", e)
            null
        }
    }

    // Shows every decoded frame at once.
    private fun drain() {
        synchronized(lock) {
            val codec = decoder ?: return
            val info = MediaCodec.BufferInfo()
            try {
                while (true) {
                    val index = codec.dequeueOutputBuffer(info, 0)
                    when {
                        index >= 0 -> codec.releaseOutputBuffer(index, true)
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> reportSize(codec.outputFormat)
                        else -> return
                    }
                }
            } catch (e: Exception) {
                fail("drain", e)
            }
        }
    }

    private fun reportSize(format: MediaFormat) {
        val w = if (format.containsKey("crop-right")) format.getInteger("crop-right") - format.getInteger("crop-left") + 1 else format.getInteger(MediaFormat.KEY_WIDTH)
        val h = if (format.containsKey("crop-bottom")) format.getInteger("crop-bottom") - format.getInteger("crop-top") + 1 else format.getInteger(MediaFormat.KEY_HEIGHT)
        main.post { onEvent(mapOf("type" to "size", "width" to w, "height" to h)) }
    }

    private fun fail(step: String, e: Exception) {
        Log.w(logTag, "pov: decoder $step failed", e)
        releaseDecoder()
        waitingKeyframe = true
        main.post { onEvent(mapOf("type" to "error", "message" to "$step: ${e.message ?: e.javaClass.simpleName}")) }
    }

    private fun releaseDecoder() {
        decoder?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        decoder = null
        waitingKeyframe = true
    }
}
