package com.example.tabletmonitor.signal

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit

class SignalingClient(
    private val onEvent: (String) -> Unit,
    private val onMessage: (SignalMessage) -> Unit,
) {
    private val httpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private var webSocket: WebSocket? = null

    fun connect(url: String) {
        val request = Request.Builder().url(url).build()
        webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                onEvent("Conectado a signaling")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val message = try {
                    SignalMessage.fromJson(text)
                } catch (_: Exception) {
                    null
                }
                if (message != null) {
                    onMessage(message)
                } else {
                    onEvent("Mensaje no valido: $text")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                onEvent("Fallo websocket: ${t.message}")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                onEvent("Conexion cerrada: $code / $reason")
            }
        })
    }

    fun send(msg: SignalMessage) {
        webSocket?.send(msg.toJson())
    }

    fun close() {
        webSocket?.close(1000, "bye")
        webSocket = null
    }
}
