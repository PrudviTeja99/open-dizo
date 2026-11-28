package bpt.studiohq.open_dizo

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class DizoNotificationListenerService : NotificationListenerService() {
    companion object {
        private var lastKey: String = ""
        private var lastTimestamp: Long = 0L
        private var lastCallNotifTime: Long = 0L
    }

    private var mediaSessionManager: MediaSessionManager? = null
    private var activeController: MediaController? = null
    private var sessionsListener: MediaSessionManager.OnActiveSessionsChangedListener? = null

    private val mediaCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            emitCurrentMediaState(activeController)
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            emitCurrentMediaState(activeController)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        initMediaSessionTracking()
    }

    override fun onListenerDisconnected() {
        cleanupMediaSessionTracking()
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        cleanupMediaSessionTracking()
        super.onDestroy()
    }

    private fun initMediaSessionTracking() {
        try {
            val componentName = ComponentName(this, DizoNotificationListenerService::class.java)
            mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            val listener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
                attachToTopController(controllers)
            }
            sessionsListener = listener
            mediaSessionManager?.addOnActiveSessionsChangedListener(listener, componentName)
            val current = mediaSessionManager?.getActiveSessions(componentName)
            attachToTopController(current)
        } catch (_: Exception) {
        }
    }

    private fun cleanupMediaSessionTracking() {
        try {
            activeController?.unregisterCallback(mediaCallback)
            activeController = null
            sessionsListener?.let { mediaSessionManager?.removeOnActiveSessionsChangedListener(it) }
            sessionsListener = null
        } catch (_: Exception) {
        }
    }

    private fun attachToTopController(controllers: List<MediaController>?) {
        activeController?.unregisterCallback(mediaCallback)
        activeController = controllers?.firstOrNull()
        activeController?.let { controller ->
            controller.registerCallback(mediaCallback)
            emitCurrentMediaState(controller)
        }
    }

    private fun emitCurrentMediaState(controller: MediaController?) {
        if (controller == null) return
        val metadata = controller.metadata
        val playbackState = controller.playbackState

        val title = metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""
        val artist = metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: ""
        val duration = metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val isPlaying = playbackState?.state == PlaybackState.STATE_PLAYING
        val position = playbackState?.position ?: 0L

        if (title.isNotEmpty() || artist.isNotEmpty()) {
            NotificationBridge.sendMusicUpdate(title, artist, duration, isPlaying, position)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == applicationContext.packageName) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""

        // Detect incoming call notifications (e.g. Dialer, Google Phone, Truecaller, VoIP)
        // before filtering ongoing flags so they trigger the watch Call Screen instead of a generic notification.
        val isCallCategory = notification.category == Notification.CATEGORY_CALL
        val isDialerPkg = pkg.contains("dialer") ||
            pkg.contains("incallui") ||
            pkg.contains("telecom") ||
            pkg.contains("truecaller")
        if (isCallCategory || isDialerPkg) {
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
            val lowerText = text.lowercase()
            val isIncoming = lowerText.contains("incoming") ||
                lowerText.contains("calling") ||
                lowerText.contains("ringing") ||
                isCallCategory
            if (isIncoming && title.isNotEmpty()) {
                val now = System.currentTimeMillis()
                if (now - lastCallNotifTime > 3000L) {
                    lastCallNotifTime = now
                    NotificationBridge.sendCallRinging(title, text)
                }
            }
            return
        }

        // Skip ongoing background services and group summaries
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) return
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val body = extractFullNotificationBody(extras)

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

    private fun extractFullNotificationBody(extras: android.os.Bundle): String {
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""

        // 1. MessagingStyle (WhatsApp, Telegram, Messages, etc.) — take the LATEST message
        // so old unread messages don't get mashed onto the newest reply.
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (messages != null && messages.isNotEmpty()) {
            val latestBundle = messages.lastOrNull() as? android.os.Bundle
            val msgText = latestBundle?.getCharSequence("text")?.toString()?.trim()
            if (!msgText.isNullOrEmpty()) {
                val sender = latestBundle.getCharSequence("sender")?.toString()?.trim()
                return if (!sender.isNullOrEmpty() && !sender.equals(title, ignoreCase = true)) {
                    "$sender: $msgText"
                } else {
                    msgText
                }
            }
        }

        // 2. BigTextStyle (expanded notification body)
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
        if (!bigText.isNullOrEmpty()) return bigText

        // 3. InboxStyle (multiple lines, e.g. Gmail / grouped messages)
        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (textLines != null && textLines.isNotEmpty()) {
            val joined = textLines.mapNotNull { it?.toString()?.trim() }
                .filter { it.isNotEmpty() }
                .joinToString("\n")
            if (joined.isNotEmpty()) return joined
        }

        // 4. Standard text / subtext fallback
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim() ?: ""
        return when {
            text.isNotEmpty() -> text
            subText.isNotEmpty() -> subText
            else -> ""
        }
    }
}
