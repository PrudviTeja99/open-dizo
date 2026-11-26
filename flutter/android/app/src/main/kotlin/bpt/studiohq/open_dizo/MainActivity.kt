package bpt.studiohq.open_dizo

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
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
}
