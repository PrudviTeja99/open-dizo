package bpt.studiohq.open_dizo

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

class PhoneCallReceiver : BroadcastReceiver() {
    companion object {
        private var lastState: String? = null
        private var sentNumberForRing: Boolean = false
        private val mainHandler = Handler(Looper.getMainLooper())
        private var pendingFallbackRunnable: Runnable? = null

        private fun cancelFallback() {
            pendingFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
            pendingFallbackRunnable = null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        @Suppress("DEPRECATION")
        val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (lastState != TelephonyManager.EXTRA_STATE_RINGING) {
                    sentNumberForRing = false
                }
                lastState = state

                if (!incomingNumber.isNullOrBlank()) {
                    cancelFallback()
                    sentNumberForRing = true
                    val callerName = resolveContactName(context, incomingNumber) ?: incomingNumber
                    NotificationBridge.sendCallRinging(callerName, incomingNumber)
                } else if (!sentNumberForRing) {
                    // On Android 9+, PHONE_STATE often broadcasts twice: first with null number,
                    // second with the actual number. Schedule a 600ms fallback so private/stripped
                    // numbers still trigger the watch call screen reliably.
                    cancelFallback()
                    val runnable = Runnable {
                        if (lastState == TelephonyManager.EXTRA_STATE_RINGING && !sentNumberForRing) {
                            sentNumberForRing = true
                            NotificationBridge.sendCallRinging("Incoming Call", "")
                        }
                    }
                    pendingFallbackRunnable = runnable
                    mainHandler.postDelayed(runnable, 600L)
                }
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK,
            TelephonyManager.EXTRA_STATE_IDLE -> {
                cancelFallback()
                if (lastState == TelephonyManager.EXTRA_STATE_RINGING) {
                    NotificationBridge.sendCallEnded()
                }
                lastState = state
                sentNumberForRing = false
            }
        }
    }

    private fun resolveContactName(context: Context, phoneNumber: String): String? {
        val hasContactsPerm = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasContactsPerm) return null

        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }
}
