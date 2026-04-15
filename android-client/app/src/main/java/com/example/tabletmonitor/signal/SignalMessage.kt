package com.example.tabletmonitor.signal

import org.json.JSONObject

sealed class SignalMessage {
    data class Join(val room: String, val role: String) : SignalMessage()
    data class Offer(val room: String, val sdp: String) : SignalMessage()
    data class Answer(val room: String, val sdp: String) : SignalMessage()
    data class IceCandidate(val room: String, val candidate: String) : SignalMessage()
    data class PeerJoined(val peerId: String, val role: String) : SignalMessage()
    data class PeerLeft(val peerId: String) : SignalMessage()
    data class Error(val message: String) : SignalMessage()

    fun toJson(): String {
        val json = JSONObject()
        when (this) {
            is Join -> {
                json.put("type", "join")
                json.put("room", room)
                json.put("role", role)
            }
            is Offer -> {
                json.put("type", "offer")
                json.put("room", room)
                json.put("sdp", sdp)
            }
            is Answer -> {
                json.put("type", "answer")
                json.put("room", room)
                json.put("sdp", sdp)
            }
            is IceCandidate -> {
                json.put("type", "ice_candidate")
                json.put("room", room)
                json.put("candidate", candidate)
            }
            is PeerJoined -> {
                json.put("type", "peer_joined")
                json.put("peer_id", peerId)
                json.put("role", role)
            }
            is PeerLeft -> {
                json.put("type", "peer_left")
                json.put("peer_id", peerId)
            }
            is Error -> {
                json.put("type", "error")
                json.put("message", message)
            }
        }
        return json.toString()
    }

    companion object {
        fun fromJson(raw: String): SignalMessage? {
            val json = JSONObject(raw)
            return when (json.optString("type")) {
                "join" -> Join(json.optString("room"), json.optString("role"))
                "offer" -> Offer(json.optString("room"), json.optString("sdp"))
                "answer" -> Answer(json.optString("room"), json.optString("sdp"))
                "ice_candidate" -> IceCandidate(json.optString("room"), json.optString("candidate"))
                "peer_joined" -> PeerJoined(json.optString("peer_id"), json.optString("role"))
                "peer_left" -> PeerLeft(json.optString("peer_id"))
                "error" -> Error(json.optString("message"))
                else -> null
            }
        }
    }
}
