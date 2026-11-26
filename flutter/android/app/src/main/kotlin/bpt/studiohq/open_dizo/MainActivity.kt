package bpt.studiohq.open_dizo

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val UPDATER_CHANNEL = "bpt.studiohq.open_dizo/updater"
    private val NOTIF_METHOD_CHANNEL = "bpt.studiohq.open_dizo/notifications"
    private val NOTIF_EVENT_CHANNEL = "bpt.studiohq.open_dizo/notifications_stream"
    private var activeRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. In-app APK updater channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist at: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                            val uri: Uri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            setDataAndType(uri, "application/vnd.android.package-archive")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Notification & Phone Call permission helpers
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessEnabled" -> {
                    val enabled = NotificationManagerCompat
                        .getEnabledListenerPackages(this)
                        .contains(packageName)
                    result.success(enabled)
                }
                "openNotificationAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "isPhonePermissionGranted" -> {
                    val phoneGranted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_PHONE_STATE
                    ) == PackageManager.PERMISSION_GRANTED
                    val callLogGranted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_CALL_LOG
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(phoneGranted && callLogGranted)
                }
                "startFindPhoneRing" -> {
                    startFindPhoneAlert()
                    result.success(true)
                }
                "stopFindPhoneRing" -> {
                    stopFindPhoneAlert()
                    result.success(true)
                }
                "startBackgroundService" -> {
                    val status = call.argument<String>("status") ?: "DIZO Watch D connected · Alerts active"
                    val intent = Intent(this, DizoBackgroundService::class.java).apply {
                        putExtra(DizoBackgroundService.EXTRA_STATUS, status)
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    val intent = Intent(this, DizoBackgroundService::class.java).apply {
                        action = DizoBackgroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                "dispatchMediaAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    handleMediaAction(action)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 3. Real-time Call & Notification event stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationBridge.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationBridge.eventSink = null
                }
            }
        )
    }

    private fun startFindPhoneAlert() {
        try {
            stopFindPhoneAlert()
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri != null) {
                activeRingtone = RingtoneManager.getRingtone(applicationContext, uri)?.apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        isLooping = true
                    }
                    play()
                }
            }
            val vibrator = getAppVibrator()
            val pattern = longArrayOf(0, 500, 300, 500, 300)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (_: Exception) {
        }
    }

    private fun stopFindPhoneAlert() {
        try {
            activeRingtone?.stop()
            activeRingtone = null
            getAppVibrator()?.cancel()
        } catch (_: Exception) {
        }
    }

    private fun getAppVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun handleMediaAction(action: String) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            when (action) {
                "play_pause" -> dispatchMediaKey(audioManager, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                "next" -> dispatchMediaKey(audioManager, KeyEvent.KEYCODE_MEDIA_NEXT)
                "previous" -> dispatchMediaKey(audioManager, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                "vol_up" -> audioManager.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_RAISE,
                    AudioManager.FLAG_SHOW_UI
                )
                "vol_down" -> audioManager.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC,
                    AudioManager.ADJUST_LOWER,
                    AudioManager.FLAG_SHOW_UI
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun dispatchMediaKey(audioManager: AudioManager, keyCode: Int) {
        val now = SystemClock.uptimeMillis()
        audioManager.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0))
        audioManager.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0))
    }
}
