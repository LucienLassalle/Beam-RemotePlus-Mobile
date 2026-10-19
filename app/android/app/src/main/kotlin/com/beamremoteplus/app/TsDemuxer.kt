package com.beamremoteplus.app

import java.io.ByteArrayOutputStream

/**
 * Minimal MPEG-TS demuxer for the point of view video of the mod: one H.264
 * stream, found through the PAT and the PMT. Joins the PES payloads of the
 * stream into access units (one per video frame) and hands each one over
 * when the next one starts, flagged corrupt when a TS packet of it was lost
 * (continuity counter gap): the decoder should then wait for a keyframe.
 */
class TsDemuxer(private val onAccessUnit: (data: ByteArray, ptsUs: Long, corrupt: Boolean) -> Unit) {
    private var pmtPid = -1
    private var videoPid = -1
    private var lastCc = -1
    private val unit = ByteArrayOutputStream(256 * 1024)
    private var unitStarted = false
    private var unitPtsUs = 0L
    private var unitCorrupt = false

    /** Feeds a datagram: whole 188-byte TS packets. */
    fun feed(data: ByteArray, length: Int) {
        var offset = 0
        while (offset + PACKET <= length) {
            if (data[offset] != SYNC) {
                offset++ // resynchronise
                continue
            }
            packet(data, offset)
            offset += PACKET
        }
    }

    /** Forgets the unit being joined (new stream, decoder reset). */
    fun reset() {
        unit.reset()
        unitStarted = false
        lastCc = -1
    }

    private fun u8(d: ByteArray, i: Int) = d[i].toInt() and 0xFF

    private fun packet(d: ByteArray, o: Int) {
        val unitStart = u8(d, o + 1) and 0x40 != 0
        val pid = ((u8(d, o + 1) and 0x1F) shl 8) or u8(d, o + 2)
        val adaptation = (u8(d, o + 3) shr 4) and 3
        val cc = u8(d, o + 3) and 0x0F
        val end = o + PACKET
        var p = o + 4
        if (adaptation and 2 != 0) p += 1 + u8(d, p)
        if (adaptation and 1 == 0 || p >= end) return // no payload
        when {
            pid == 0 -> if (unitStart) parsePat(d, p, end)
            pid == pmtPid -> if (unitStart) parsePmt(d, p, end)
            pid == videoPid -> video(d, p, end, unitStart, cc)
        }
    }

    // Start of the section after the pointer field, and its end before the CRC.
    private fun section(d: ByteArray, p: Int, end: Int): Pair<Int, Int>? {
        val s = p + 1 + u8(d, p)
        if (s + 8 > end) return null
        val length = ((u8(d, s + 1) and 0x0F) shl 8) or u8(d, s + 2)
        return Pair(s, minOf(s + 3 + length - 4, end))
    }

    private fun parsePat(d: ByteArray, p: Int, end: Int) {
        val (s, sectionEnd) = section(d, p, end) ?: return
        var i = s + 8
        while (i + 4 <= sectionEnd) {
            val program = (u8(d, i) shl 8) or u8(d, i + 1)
            if (program != 0) {
                pmtPid = ((u8(d, i + 2) and 0x1F) shl 8) or u8(d, i + 3)
                return
            }
            i += 4
        }
    }

    private fun parsePmt(d: ByteArray, p: Int, end: Int) {
        val (s, sectionEnd) = section(d, p, end) ?: return
        if (s + 12 > end) return
        var i = s + 12 + (((u8(d, s + 10) and 0x0F) shl 8) or u8(d, s + 11))
        while (i + 5 <= sectionEnd) {
            val type = u8(d, i)
            val pid = ((u8(d, i + 1) and 0x1F) shl 8) or u8(d, i + 2)
            if (type == STREAM_TYPE_H264) {
                if (pid != videoPid) reset()
                videoPid = pid
                return
            }
            i += 5 + (((u8(d, i + 3) and 0x0F) shl 8) or u8(d, i + 4))
        }
    }

    private fun video(d: ByteArray, p: Int, end: Int, unitStart: Boolean, cc: Int) {
        if (lastCc >= 0 && cc != (lastCc + 1) and 0x0F) unitCorrupt = true // TS packets lost
        lastCc = cc
        if (unitStart) {
            flush()
            // PES header: 00 00 01, stream id, length (2), flags (2), header length.
            if (end - p < 9 || u8(d, p) != 0 || u8(d, p + 1) != 0 || u8(d, p + 2) != 1) return
            val headerEnd = p + 9 + u8(d, p + 8)
            if (headerEnd > end) return
            unitPtsUs = if (u8(d, p + 7) and 0x80 != 0) pts(d, p + 9) * 100 / 9 else 0L // 90 kHz to µs
            unitStarted = true
            unit.write(d, headerEnd, end - headerEnd)
        } else if (unitStarted) {
            unit.write(d, p, end - p)
        }
    }

    private fun pts(d: ByteArray, i: Int): Long =
        ((u8(d, i).toLong() shr 1) and 0x07L shl 30) or
            (u8(d, i + 1).toLong() shl 22) or ((u8(d, i + 2).toLong() shr 1) shl 15) or
            (u8(d, i + 3).toLong() shl 7) or (u8(d, i + 4).toLong() shr 1)

    private fun flush() {
        if (unitStarted && unit.size() > 0) onAccessUnit(unit.toByteArray(), unitPtsUs, unitCorrupt)
        unit.reset()
        unitStarted = false
        unitCorrupt = false
    }

    companion object {
        const val PACKET = 188
        private const val SYNC = 0x47.toByte()
        private const val STREAM_TYPE_H264 = 0x1B

        /** True when the access unit holds an IDR picture (a keyframe). */
        fun isKeyframe(au: ByteArray): Boolean {
            var i = 0
            while (i + 3 < au.size) {
                if (au[i].toInt() == 0 && au[i + 1].toInt() == 0 && au[i + 2].toInt() == 1) {
                    if (au[i + 3].toInt() and 0x1F == 5) return true
                    i += 3
                } else {
                    i++
                }
            }
            return false
        }
    }
}
