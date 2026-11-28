package bpt.studiohq.open_dizo

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
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
import android.service.notification.NotificationListenerService
import android.telecom.TelecomManager
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
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

    override fun onResume() {
        super.onResume()
        rebindNotificationListenerIfEnabled()
    }

    private fun rebindNotificationListenerIfEnabled() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val enabled = NotificationManagerCompat
                    .getEnabledListenerPackages(this)
                    .contains(packageName)
                if (enabled) {
                    NotificationListenerService.requestRebind(
                        ComponentName(this, DizoNotificationListenerService::class.java)
                    )
                }
            } catch (_: Exception) {
            }
        }
    }

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
                    val answerGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.ANSWER_PHONE_CALLS
                        ) == PackageManager.PERMISSION_GRANTED
                    } else {
                        true
                    }
                    result.success(phoneGranted && callLogGranted && answerGranted)
                }
                "requestPhonePermissions" -> {
                    val perms = mutableListOf(
                        Manifest.permission.READ_PHONE_STATE,
                        Manifest.permission.READ_CALL_LOG,
                        Manifest.permission.READ_CONTACTS
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        perms.add(Manifest.permission.ANSWER_PHONE_CALLS)
                    }
                    ActivityCompat.requestPermissions(this, perms.toTypedArray(), 1001)
                    result.success(true)
                }
                "endPhoneCall" -> {
                    result.success(endIncomingCall())
                }
                "mutePhoneCall" -> {
                    result.success(muteIncomingCall())
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "text/plain"
                    val title = call.argument<String>("title") ?: "Share File"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                type = mimeType
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(shareIntent, title))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    }
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
                "getLastKnownLocation" -> {
                    val fineGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val coarseGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!fineGranted && !coarseGranted) {
                        result.error("PERMISSION_DENIED", "Location permission not granted", null)
                        return@setMethodCallHandler
                    }
                    val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    if (lm == null) {
                        result.error("UNAVAILABLE", "LocationManager unavailable", null)
                        return@setMethodCallHandler
                    }
                    val providers = listOf(
                        LocationManager.GPS_PROVIDER,
                        LocationManager.NETWORK_PROVIDER,
                        LocationManager.PASSIVE_PROVIDER
                    )
                    @Suppress("MissingPermission")
                    val best: Location? = providers
                        .mapNotNull { p ->
                            try { lm.getLastKnownLocation(p) } catch (_: Exception) { null }
                        }
                        .maxByOrNull { it.accuracy * -1 + it.time } // prefer recent + accurate
                    if (best != null) {
                        result.success(mapOf("lat" to best.latitude, "lon" to best.longitude))
                    } else {
                        result.error("NO_LOCATION", "No last known location available", null)
                    }
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

    @Suppress("DEPRECATION")
    private fun endIncomingCall(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val hasPerm = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ANSWER_PHONE_CALLS
                ) == PackageManager.PERMISSION_GRANTED
                if (hasPerm) {
                    val telecom = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                    if (telecom != null && telecom.endCall()) {
                        return true
                    }
                }
            }
            // Fallback for older devices or restricted OEMs
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                dispatchMediaKey(audioManager, KeyEvent.KEYCODE_HEADSETHOOK)
                return true
            }
        } catch (_: Exception) {
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun muteIncomingCall(): Boolean {
        var silenced = false
        // Silence ONLY the current incoming call ringer without muting the phone's ringer volume.
        // 1. TelecomManager.silenceRinger() silences the active incoming call cleanly.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val hasPerm = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.READ_PHONE_STATE
                ) == PackageManager.PERMISSION_GRANTED
                if (hasPerm) {
                    val telecom = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                    telecom?.silenceRinger()
                    silenced = true
                }
            } catch (_: Exception) {
            }
        }
        // 2. Dispatch KEYCODE_VOLUME_DOWN — Android InCallUI silences only the current ring
        //    without permanently muting STREAM_RING for future calls.
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audioManager != null) {
            try {
                dispatchMediaKey(audioManager, KeyEvent.KEYCODE_VOLUME_DOWN)
                silenced = true
            } catch (_: Exception) {
            }
        }
        return silenced
    }
}
