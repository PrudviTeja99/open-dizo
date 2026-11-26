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
