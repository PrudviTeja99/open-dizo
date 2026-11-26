package bpt.studiohq.open_dizo

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

class PhoneCallReceiver : BroadcastReceiver() {
    companion object {
        private var lastState: String? = null
        private var sentNumberForRing: Boolean = false
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
                    sentNumberForRing = true
                    val callerName = resolveContactName(context, incomingNumber) ?: incomingNumber
                    NotificationBridge.sendCallRinging(callerName, incomingNumber)
                } else if (!sentNumberForRing) {
                    // On Android 9+, PHONE_STATE broadcasts twice when READ_CALL_LOG is granted:
                    // first with null number, second with the actual number.
                    val hasCallLogPerm = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.READ_CALL_LOG
                    ) == PackageManager.PERMISSION_GRANTED

                    if (!hasCallLogPerm) {
                        sentNumberForRing = true
                        NotificationBridge.sendCallRinging("Incoming Call", "")
                    }
                }
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK,
            TelephonyManager.EXTRA_STATE_IDLE -> {
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
