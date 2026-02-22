#!/usr/bin/env kotlin

// Quick FCast protocol sender for testing the receiver in the tvOS simulator.
// Usage: kotlin fcast-sender.main.kts [url] [container]
//
// Examples:
//   kotlin fcast-sender.main.kts                          # plays test MKV
//   kotlin fcast-sender.main.kts "http://url/file.mkv" "video/x-matroska"
//   kotlin fcast-sender.main.kts "http://url/img.png" "image/png"

import java.io.OutputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder

fun sendFrame(out: OutputStream, opcode: Int, json: String? = null) {
    val body = json?.toByteArray(Charsets.UTF_8) ?: ByteArray(0)
    val length = 1 + body.size
    val header = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(length).array()
    out.write(header)
    out.write(opcode)
    if (body.isNotEmpty()) out.write(body)
    out.flush()
}

fun readFrame(socket: Socket): Pair<Int, String?> {
    val input = socket.getInputStream()
    val lenBuf = ByteArray(4)
    var read = 0
    while (read < 4) read += input.read(lenBuf, read, 4 - read)
    val length = ByteBuffer.wrap(lenBuf).order(ByteOrder.LITTLE_ENDIAN).int
    val payload = ByteArray(length)
    read = 0
    while (read < length) read += input.read(payload, read, length - read)
    val opcode = payload[0].toInt() and 0xFF
    val body = if (length > 1) String(payload, 1, length - 1, Charsets.UTF_8) else null
    return opcode to body
}

// --- Public test media files ---
val TEST_MKV = "https://test-videos.co/pool/Big_Buck_Bunny_1080_10s_5MB.mkv"
val TEST_WEBM = "https://test-videos.co/pool/Big_Buck_Bunny_720_10s_2MB.webm"
val TEST_MP4 = "https://test-videos.co/pool/Big_Buck_Bunny_1080_10s_5MB.mp4"
val TEST_IMAGE = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/560px-PNG_transparency_demonstration_1.png"

val url = args.getOrNull(0) ?: TEST_MKV
val container = args.getOrNull(1) ?: when {
    url.endsWith(".mkv") -> "video/x-matroska"
    url.endsWith(".webm") -> "video/webm"
    url.endsWith(".mp4") -> "video/mp4"
    url.endsWith(".png") -> "image/png"
    url.endsWith(".jpg") || url.endsWith(".jpeg") -> "image/jpeg"
    else -> "video/x-matroska"
}

println("Connecting to localhost:46899...")
val socket = Socket("127.0.0.1", 46899)
val out = socket.getOutputStream()
println("Connected!")

// Step 1: Send version handshake (opcode 11)
println("-> Sending version...")
sendFrame(out, 11, """{"version":3}""")

// Read version response
val (vOp, vBody) = readFrame(socket)
println("<- Version response (opcode=$vOp): $vBody")

// Step 2: Send play message (opcode 1)
val playJson = """{"container":"$container","url":"$url"}"""
println("-> Sending play: $playJson")
sendFrame(out, 1, playJson)

// Step 3: Listen for playback updates
println("Listening for playback updates (Ctrl+C to quit)...")
try {
    while (true) {
        val (op, body) = readFrame(socket)
        val opName = when (op) {
            6 -> "PlaybackUpdate"
            7 -> "VolumeUpdate"
            9 -> "PlaybackError"
            else -> "Opcode($op)"
        }
        println("<- $opName: $body")
        if (op == 9) {
            println("ERROR from receiver! Exiting.")
            break
        }
    }
} catch (e: Exception) {
    println("Connection closed: ${e.message}")
}

socket.close()
println("Done.")
