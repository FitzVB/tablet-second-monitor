package com.example.tabletmonitor

import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Bundle
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.tabletmonitor.signal.SignalMessage
import com.example.tabletmonitor.signal.SignalingClient
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private lateinit var signalingClient: SignalingClient
    private var streamSocket: WebSocket? = null

    private lateinit var roomInput: EditText
    private lateinit var connectButton: Button
    private lateinit var statusText: TextView
    private lateinit var logText: TextView
    private lateinit var topPanel: LinearLayout
    private lateinit var streamSurface: SurfaceView
    private lateinit var logScroll: ScrollView

    private val okHttpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private val usbSignalingUrl = "ws://127.0.0.1:9001/ws"
    private val usbH264Url = "ws://127.0.0.1:9001/h264"

    private var connected = false
    private var decoder: H264Decoder? = null
    private var surfaceReady = false
    private var pendingStreamStart = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_main)

        roomInput = findViewById(R.id.roomInput)
        connectButton = findViewById(R.id.connectButton)
        statusText = findViewById(R.id.statusText)
        logText = findViewById(R.id.logText)
        topPanel = findViewById(R.id.topPanel)
        streamSurface = findViewById(R.id.streamSurface)
        logScroll = findViewById(R.id.logScroll)

        signalingClient = SignalingClient(
            onEvent = { event -> runOnUiThread { appendLog(event) } },
            onMessage = { message -> runOnUiThread { appendLog("RX: $message") } }
        )

        streamSurface.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                surfaceReady = true
                maybeStartPendingStream("Surface lista, iniciando video H.264...")
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                surfaceReady = true
                maybeStartPendingStream("Surface actualizada, iniciando video H.264...")
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {
                surfaceReady = false
                pendingStreamStart = false
                decoder?.release()
                decoder = null
            }
        })

        connectButton.setOnClickListener {
            if (!connected) {
                val room = roomInput.text.toString().trim().ifBlank { "room-1" }

                signalingClient.connect(usbSignalingUrl)
                signalingClient.send(SignalMessage.Join(room, role = "android_client"))

                startH264Stream()

                connected = true
                statusText.text = "Estado: conectando video H.264..."
                connectButton.text = "Desconectar"
                appendLog("USB: ADB reverse activo, room=$room")
            } else {
                stopAll()
            }
        }
    }

    private fun startH264Stream() {
        if (!surfaceReady) {
            pendingStreamStart = true
            appendLog("Surface no lista todavia, esperando...")
            return
        }

        pendingStreamStart = false
        if (streamSocket != null) {
            return
        }

        val metrics = resources.displayMetrics
        val rawW = metrics.widthPixels.coerceAtLeast(1)
        val rawH = metrics.heightPixels.coerceAtLeast(1)

        val maxSide = maxOf(rawW, rawH)
        val targetMax = 960.0
        val down = if (maxSide > targetMax) maxSide / targetMax else 1.0
        val targetW = (rawW / down).toInt().coerceAtLeast(320)
        val targetH = (rawH / down).toInt().coerceAtLeast(240)

        decoder?.release()
        decoder = H264Decoder(streamSurface.holder.surface, targetW, targetH)

        val streamUrl = "$usbH264Url?w=$targetW&h=$targetH&fps=60&bitrate_kbps=3500&fit=cover"
        val request = Request.Builder().url(streamUrl).build()

        streamSocket = okHttpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                runOnUiThread {
                    streamSurface.visibility = View.VISIBLE
                    logScroll.visibility = View.GONE
                    topPanel.visibility = View.GONE
                    setImmersiveMode(true)
                    statusText.text = "Estado: video H.264 activo"
                }
            }

            override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
                decoder?.feed(bytes.toByteArray())
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                runOnUiThread { appendLog("WS: $text") }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                runOnUiThread {
                    appendLog("H264 stream error: ${t.message}")
                    statusText.text = "Estado: error de stream"
                    streamSocket = null
                    stopVisualStreamingState()
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                runOnUiThread {
                    appendLog("H264 stream cerrado: $reason")
                    streamSocket = null
                    stopVisualStreamingState()
                }
            }
        })
    }

    private fun maybeStartPendingStream(logMessage: String) {
        if (!connected || !pendingStreamStart || streamSocket != null) {
            return
        }
        runOnUiThread {
            appendLog(logMessage)
            statusText.text = "Estado: iniciando video H.264..."
        }
        startH264Stream()
    }

    private fun stopVisualStreamingState() {
        streamSurface.visibility = View.GONE
        logScroll.visibility = View.VISIBLE
        topPanel.visibility = View.VISIBLE
        setImmersiveMode(false)
    }

    private fun stopAll() {
        streamSocket?.close(1000, "desconectado por usuario")
        streamSocket = null
        pendingStreamStart = false
        signalingClient.close()
        decoder?.release()
        decoder = null
        connected = false
        runOnUiThread {
            stopVisualStreamingState()
            statusText.text = "Estado: desconectado"
            connectButton.text = "Conectar"
        }
    }

    private fun setImmersiveMode(enabled: Boolean) {
        @Suppress("DEPRECATION")
        if (enabled) {
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        } else {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }

    override fun onDestroy() {
        stopAll()
        okHttpClient.dispatcher.executorService.shutdown()
        super.onDestroy()
    }

    private fun appendLog(line: String) {
        logText.append("\n$line")
    }
}

private class H264Decoder(surface: Surface, width: Int, height: Int) {
    private val codec: MediaCodec = MediaCodec.createDecoderByType("video/avc")
    private val parser = AnnexBParser { nal -> queueNal(nal) }

    init {
        val format = MediaFormat.createVideoFormat("video/avc", width, height)
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, width * height)
        codec.configure(format, surface, null, 0)
        codec.start()
    }

    fun feed(chunk: ByteArray) {
        parser.push(chunk)
        drainOutput()
    }

    private fun queueNal(nal: ByteArray) {
        if (nal.isEmpty()) return
        val index = codec.dequeueInputBuffer(0)
        if (index < 0) return

        val input = codec.getInputBuffer(index) ?: return
        input.clear()
        if (input.capacity() < nal.size) {
            codec.queueInputBuffer(index, 0, 0, 0, 0)
            return
        }

        input.put(nal)
        val nalType = nal[0].toInt() and 0x1F
        val flags = if (nalType == 7 || nalType == 8) MediaCodec.BUFFER_FLAG_CODEC_CONFIG else 0
        codec.queueInputBuffer(index, 0, nal.size, System.nanoTime() / 1000, flags)
    }

    private fun drainOutput() {
        val info = MediaCodec.BufferInfo()
        while (true) {
            val outIndex = codec.dequeueOutputBuffer(info, 0)
            if (outIndex >= 0) {
                codec.releaseOutputBuffer(outIndex, true)
            } else {
                break
            }
        }
    }

    fun release() {
        try {
            codec.stop()
        } catch (_: Throwable) {
        }
        try {
            codec.release()
        } catch (_: Throwable) {
        }
    }
}

private class AnnexBParser(private val onNal: (ByteArray) -> Unit) {
    private var stash = ByteArray(0)

    fun push(chunk: ByteArray) {
        if (chunk.isEmpty()) return
        val merged = ByteArray(stash.size + chunk.size)
        System.arraycopy(stash, 0, merged, 0, stash.size)
        System.arraycopy(chunk, 0, merged, stash.size, chunk.size)
        stash = merged

        var current = findStartCode(stash, 0) ?: return
        var next = findStartCode(stash, current.first + current.second)

        while (next != null) {
            val nalStart = current.first + current.second
            val nalEnd = next.first
            if (nalEnd > nalStart) {
                val nal = stash.copyOfRange(nalStart, nalEnd)
                onNal(nal)
            }
            current = next
            next = findStartCode(stash, current.first + current.second)
        }

        stash = stash.copyOfRange(current.first, stash.size)
        if (stash.size > 2_000_000) {
            stash = stash.copyOfRange(stash.size - 200_000, stash.size)
        }
    }

    private fun findStartCode(data: ByteArray, from: Int): Pair<Int, Int>? {
        var i = from
        while (i + 3 < data.size) {
            if (data[i] == 0.toByte() && data[i + 1] == 0.toByte()) {
                if (data[i + 2] == 1.toByte()) {
                    return i to 3
                }
                if (i + 3 < data.size && data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte()) {
                    return i to 4
                }
            }
            i++
        }
        return null
    }
}
