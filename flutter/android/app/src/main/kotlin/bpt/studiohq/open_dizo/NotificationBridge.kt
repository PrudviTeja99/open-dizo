package bpt.studiohq.open_dizo

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe bridge forwarding native Android call & notification events
 * to Flutter's BleService via EventChannel.
 */
object NotificationBridge {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    var eventSink: EventChannel.EventSink? = null

    fun sendCallRinging(callerName: String, phoneNumber: String) {
        val payload = hashMapOf<String, Any>(
            "event" to "call_ringing",
            "callerName" to callerName,
            "phoneNumber" to phoneNumber
        )
        emit(payload)
    }

    fun sendCallEnded() {
        val payload = hashMapOf<String, Any>(
            "event" to "call_ended"
        )
        emit(payload)
    }

    fun sendNotification(packageName: String, title: String, body: String) {
        val payload = hashMapOf<String, Any>(
            "event" to "notification",
            "packageName" to packageName,
            "title" to title,
            "body" to body
        )
        emit(payload)
    }

    private fun emit(payload: Map<String, Any>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(payload)
            } catch (_: Exception) {
            }
        }
    }
}
