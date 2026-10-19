package com.beamremoteplus.app

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TsDemuxerTest {
    private val videoPid = 0x100

    private class Unit(val data: ByteArray, val ptsUs: Long, val corrupt: Boolean)

    // One 188-byte TS packet; the payload is padded with an adaptation field.
    private fun packet(pid: Int, start: Boolean, cc: Int, payload: ByteArray): ByteArray {
        val p = ByteArray(188) { 0xFF.toByte() }
        p[0] = 0x47
        p[1] = ((if (start) 0x40 else 0) or (pid shr 8)).toByte()
        p[2] = (pid and 0xFF).toByte()
        val stuffing = 184 - payload.size
        if (stuffing > 0) {
            p[3] = (0x30 or cc).toByte()
            p[4] = (stuffing - 1).toByte()
            if (stuffing > 1) p[5] = 0
        } else {
            p[3] = (0x10 or cc).toByte()
        }
        payload.copyInto(p, 188 - payload.size)
        return p
    }

    private fun bytes(vararg b: Int) = ByteArray(b.size) { b[it].toByte() }

    private val pat = packet(0, true, 0, bytes(0, 0x00, 0xB0, 13, 0, 1, 0xC1, 0, 0, 0, 1, 0xF0, 0x00, 0, 0, 0, 0))
    private val pmt = packet(0x1000, true, 0, bytes(
        0, 0x02, 0xB0, 18, 0, 1, 0xC1, 0, 0, 0xE1, 0x00, 0xF0, 0x00,
        0x1B, 0xE1, 0x00, 0xF0, 0x00, 0, 0, 0, 0))

    // A PES with a PTS of 90000 (1 s) and the given payload, cut in TS packets.
    private fun pes(payload: ByteArray, cc0: Int): List<ByteArray> {
        val header = bytes(0, 0, 1, 0xE0, 0, 0, 0x80, 0x80, 5, 0x21, 0x00, 0x05, 0xBF, 0x21)
        val all = header + payload
        val packets = mutableListOf<ByteArray>()
        var offset = 0
        var cc = cc0
        while (offset < all.size) {
            val n = minOf(184, all.size - offset)
            packets.add(packet(videoPid, offset == 0, cc and 0x0F, all.copyOfRange(offset, offset + n)))
            offset += n
            cc++
        }
        return packets
    }

    private fun run(vararg packets: ByteArray): List<Unit> {
        val units = mutableListOf<Unit>()
        val demuxer = TsDemuxer { data, pts, corrupt -> units.add(Unit(data, pts, corrupt)) }
        val datagram = packets.fold(ByteArray(0)) { acc, p -> acc + p }
        demuxer.feed(datagram, datagram.size)
        return units
    }

    private val idr = bytes(0, 0, 0, 1, 0x67, 1, 2, 0, 0, 0, 1, 0x65, 9, 9)
    private val big = ByteArray(500) { (it % 200 + 1).toByte() }

    @Test
    fun joinsTheAccessUnitsOfTheVideoStream() {
        val first = pes(big, 0)
        val second = pes(idr, first.size)
        val units = run(pat, pmt, *first.toTypedArray(), *second.toTypedArray(), *pes(idr, first.size + second.size).toTypedArray())
        assertEquals(2, units.size) // the last one is handed over when the next starts
        assertArrayEquals(big, units[0].data)
        assertEquals(1_000_000L, units[0].ptsUs)
        assertFalse(units[0].corrupt)
        assertArrayEquals(idr, units[1].data)
    }

    @Test
    fun flagsAUnitThatLostAPacket() {
        val first = pes(big, 0)
        val units = run(pat, pmt, first[0], first[2], *pes(idr, first.size).toTypedArray(), *pes(idr, first.size + 1).toTypedArray())
        assertTrue(units[0].corrupt)
        assertFalse(units[1].corrupt)
    }

    @Test
    fun ignoresEverythingBeforeThePmt() {
        assertTrue(run(*pes(idr, 0).toTypedArray(), *pes(idr, 1).toTypedArray()).isEmpty())
    }

    @Test
    fun findsKeyframes() {
        assertTrue(TsDemuxer.isKeyframe(idr))
        assertFalse(TsDemuxer.isKeyframe(bytes(0, 0, 0, 1, 0x41, 1, 2)))
    }
}
