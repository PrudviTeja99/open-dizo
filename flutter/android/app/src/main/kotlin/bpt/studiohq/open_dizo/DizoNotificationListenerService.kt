package bpt.studiohq.open_dizo

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DizoNotificationListenerService : NotificationListenerService() {
    companion object {
        private var lastKey: String = ""
        private var lastTimestamp: Long = 0L
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == applicationContext.packageName) return

        val notification = sbn.notification ?: return
        // Skip ongoing background services and group summaries
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) return
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
        val body = if (!bigText.isNullOrEmpty()) bigText else (text ?: "")

        if (title.isEmpty() && body.isEmpty()) return

        // Deduplicate rapid duplicate notifications
        val now = System.currentTimeMillis()
        val dedupKey = "$pkg|$title|$body"
        if (dedupKey == lastKey && (now - lastTimestamp) < 2000L) {
            return
        }
        lastKey = dedupKey
        lastTimestamp = now

        NotificationBridge.sendNotification(pkg, title, body)
    }
}
