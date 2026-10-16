package com.example.personal_finance

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val methodChannelSyncName = "com.example.personal_finance/notification_sync"
    private val eventChannelSyncName = "com.example.personal_finance/notification_stream"
    private val methodChannelDispatchName = "com.example.personal_finance/notifications"

    private var eventSink: EventChannel.EventSink? = null
    private var initialPayload: String? = null
    private var notificationMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.getStringExtra("payload")?.let {
            initialPayload = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("payload")?.let { payload ->
            initialPayload = payload
            notificationMethodChannel?.invokeMethod("onNotificationClicked", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Inicializar canales de notificación del sistema
        NotificationHelper.createChannels(applicationContext)

        // MethodChannel para sincronización y escucha de bancos
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelSyncName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "requestPermission" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "rebindService" -> {
                    val success = rebindNotificationService()
                    result.success(success)
                }
                "getQueuedNotifications" -> {
                    val queued = BalanceNotificationListenerService.getQueuedNotifications(applicationContext)
                    result.success(queued)
                }
                "clearQueuedNotifications" -> {
                    BalanceNotificationListenerService.clearQueuedNotifications(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel para emisión y despacho de notificaciones locales de la app
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelDispatchName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> {
                        val granted = NotificationHelper.areNotificationsEnabled(applicationContext)
                        result.success(granted)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val hasPermission = ActivityCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) == PackageManager.PERMISSION_GRANTED
                            if (!hasPermission) {
                                ActivityCompat.requestPermissions(
                                    this@MainActivity,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    1010
                                )
                            }
                            result.success(hasPermission)
                        } else {
                            result.success(NotificationHelper.areNotificationsEnabled(applicationContext))
                        }
                    }
                    "showNotification" -> {
                        val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                        val title = call.argument<String>("title") ?: "Balance App"
                        val body = call.argument<String>("body") ?: ""
                        val channelId = call.argument<String>("channelId") ?: NotificationHelper.CHANNEL_BANK_SYNC
                        val payload = call.argument<String>("payload")

                        NotificationHelper.showNotification(
                            context = applicationContext,
                            id = id,
                            title = title,
                            body = body,
                            channelId = channelId,
                            payload = payload
                        )
                        result.success(true)
                    }
                    "cancelNotification" -> {
                        val id = call.argument<Int>("id") ?: 0
                        NotificationHelper.cancelNotification(applicationContext, id)
                        result.success(true)
                    }
                    "getInitialPayload" -> {
                        val p = initialPayload
                        initialPayload = null
                        result.success(p)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // EventChannel para recepción en tiempo real de notificaciones bancarias
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelSyncName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    BalanceNotificationListenerService.notificationCallback = { data ->
                        runOnUiThread {
                            eventSink?.success(data)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    BalanceNotificationListenerService.notificationCallback = null
                }
            }
        )
    }

    override fun onResume() {
        super.onResume()
        if (isNotificationServiceEnabled()) {
            rebindNotificationService()
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        try {
            val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
            if (enabledPackages.contains(pkgName)) {
                return true
            }
        } catch (e: Exception) {
            // Fallback
        }

        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":".toRegex()).toTypedArray()
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && TextUtils.equals(pkgName, cn.packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun rebindNotificationService(): Boolean {
        val componentName = ComponentName(applicationContext, BalanceNotificationListenerService::class.java)
        var success = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                NotificationListenerService.requestRebind(componentName)
                success = true
            } catch (e: Exception) {
                // Ignore
            }
        }

        try {
            val pm = packageManager
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            success = true
        } catch (e: Exception) {
            // Ignore
        }

        return success
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
