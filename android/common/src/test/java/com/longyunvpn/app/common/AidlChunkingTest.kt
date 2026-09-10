package com.longyunvpn.app.common

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Every reply from the core crosses a Binder transaction to reach the app, and
 * Binder caps a transaction at roughly 1 MB for the whole process. The proxy
 * list is the payload that gets close: a large subscription is hundreds of
 * kilobytes of JSON, and it is exactly the payload behind "the server list is
 * empty" on one device and fine on the next.
 *
 * Chunking is what keeps it under the cap. It has no device dependency, so it
 * can be held to its contract here rather than discovered in the field:
 * everything sent arrives, in order, in pieces Binder will carry.
 */
class AidlChunkingTest {

    /** Comfortably under Binder's ~1 MB per-transaction ceiling. */
    private val binderSafeLimit = 512 * 1024

    @Test
    fun `an empty payload still produces one chunk`() {
        // Callers loop over the chunks and flag the last as completion. No
        // chunks meant the loop never ran, the callback never fired, and the
        // Flutter call waited out its timeout instead of getting an empty
        // result straight away.
        val chunks = "".chunkedForAidl()
        assertEquals(1, chunks.size)
        assertEquals(0, chunks.first().size)
    }

    @Test
    fun `a small payload is sent whole`() {
        val json = """{"proxies":[]}"""
        val chunks = json.chunkedForAidl()
        assertEquals(1, chunks.size)
        assertEquals(json, chunks.formatString())
    }

    @Test
    fun `a realistic proxy list survives the round trip intact`() {
        // Roughly the shape of a large subscription: many nodes, non-ASCII
        // names, several hundred kilobytes.
        val payload = buildString {
            append("""{"proxies":[""")
            repeat(4000) { i ->
                if (i > 0) append(',')
                append("""{"name":"HK 香港L%02d | x1","type":"vmess","server":"a%d.example.com"}"""
                    .format(i % 100, i))
            }
            append("]}")
        }
        val chunks = payload.chunkedForAidl()
        assertTrue("payload should need splitting", chunks.size > 1)
        assertEquals(payload, chunks.formatString())
    }

    @Test
    fun `no chunk exceeds what Binder will carry`() {
        for (size in listOf(200 * 1024, 2 * 1024 * 1024, 12 * 1024 * 1024)) {
            val chunks = "x".repeat(size).chunkedForAidl()
            val largest = chunks.maxOf { it.size }
            assertTrue(
                "a $size byte payload produced a $largest byte chunk",
                largest <= binderSafeLimit,
            )
        }
    }

    @Test
    fun `chunks reassemble in the order they were produced`() {
        val payload = (0 until 50_000).joinToString(",") { it.toString() }
        val chunks = payload.chunkedForAidl()
        assertEquals(payload, chunks.formatString())
    }

    @Test
    fun `no byte is dropped or duplicated at a chunk boundary`() {
        val payload = "y".repeat(300 * 1024)
        val chunks = payload.chunkedForAidl()
        assertEquals(payload.length, chunks.sumOf { it.size })
    }

    @Test
    fun `a multi-byte character is not split across chunks by reassembly`() {
        // Chunking is by bytes, so a UTF-8 sequence can straddle a boundary.
        // That is fine only because the pieces are rejoined as bytes before
        // decoding — decoding each chunk on its own would corrupt the name of
        // every node whose label is not ASCII, which is most of them here.
        val payload = "香港节点".repeat(80_000)
        val chunks = payload.chunkedForAidl()
        assertTrue("payload should need splitting", chunks.size > 1)
        assertEquals(payload, chunks.formatString())
    }

    @Test
    fun `a payload one byte over a chunk size splits cleanly`() {
        val payload = "z".repeat(64 * 1024 + 1)
        val chunks = payload.chunkedForAidl()
        assertEquals(payload, chunks.formatString())
        assertEquals(payload.length, chunks.sumOf { it.size })
    }

    @Test
    fun `the bytes of the first chunk are the start of the payload`() {
        val payload = "abcdefghij".repeat(40_000)
        val chunks = payload.chunkedForAidl()
        val head = payload.toByteArray().copyOfRange(0, chunks.first().size)
        assertArrayEquals(head, chunks.first())
    }
}
