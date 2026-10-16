package com.example.personal_finance

import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class BalanceNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val PREFS_NAME = "balance_notification_prefs"
        private const val KEY_QUEUED_NOTIFICATIONS = "queued_notifications"

        var notificationCallback: ((Map<String, Any?>) -> Unit)? = null
        var isConnected = false

        fun getQueuedNotifications(context: Context): List<Map<String, Any?>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val jsonString = prefs.getString(KEY_QUEUED_NOTIFICATIONS, null) ?: return emptyList()
            return try {
                val array = JSONArray(jsonString)
                val list = mutableListOf<Map<String, Any?>>()
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    list.add(
                        mapOf(
                            "packageName" to obj.optString("packageName"),
                            "title" to obj.optString("title"),
                            "text" to obj.optString("text"),
                            "subText" to obj.optString("subText"),
                            "timestamp" to obj.optLong("timestamp")
                        )
                    )
                }
                list
            } catch (e: Exception) {
                emptyList()
            }
        }

        fun clearQueuedNotifications(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_QUEUED_NOTIFICATIONS).apply()
        }

        fun queueNotification(context: Context, data: Map<String, Any?>) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingJson = prefs.getString(KEY_QUEUED_NOTIFICATIONS, "[]")
            try {
                val array = JSONArray(existingJson)
                val newObj = JSONObject(data)
                array.put(newObj)
                while (array.length() > 50) {
                    array.remove(0)
                }
                prefs.edit().putString(KEY_QUEUED_NOTIFICATIONS, array.toString()).apply()
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, BalanceNotificationListenerService::class.java))
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        // Ignorar notificaciones generadas por la propia aplicación
        if (packageName == applicationContext.packageName) return

        val extras = sbn.notification?.extras ?: return

        // Extraer título con soporte para BigTextStyle
        val title = extras.getCharSequence("android.title.big")?.toString()
            ?: extras.getCharSequence("android.title")?.toString()
            ?: ""

        // Extraer texto contemplando estilos BigText, InboxStyle (textLines) y standard
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val textLines = extras.getCharSequenceArray("android.textLines")?.joinToString(" ") ?: ""
        val subText = extras.getCharSequence("android.subText")?.toString() ?: ""
        val tickerText = sbn.notification?.tickerText?.toString() ?: ""

        val effectiveText = when {
            bigText.isNotEmpty() -> bigText
            text.isNotEmpty() -> text
            textLines.isNotEmpty() -> textLines
            tickerText.isNotEmpty() -> tickerText
            else -> ""
        }

        if (title.isEmpty() && effectiveText.isEmpty()) return

        val notificationData = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to effectiveText,
            "subText" to subText,
            "timestamp" to sbn.postTime
        )

        val callback = notificationCallback
        if (callback != null) {
            callback(notificationData)
        } else {
            queueNotification(applicationContext, notificationData)

            // Si la app está en segundo plano y corresponde a una notificación bancaria legítima,
            // notificar al usuario para que pueda acceder y confirmar con 1 toque.
            if (isEligibleFinancialNotification(packageName, "$title $effectiveText")) {
                NotificationHelper.showNotification(
                    context = applicationContext,
                    id = (sbn.postTime % 100000).toInt(),
                    title = "💳 Transacción detectada",
                    body = "Se detectó un movimiento reciente. Toca para registrarlo en Balance.",
                    channelId = NotificationHelper.CHANNEL_BANK_SYNC,
                    payload = "{\"action\":\"open_bank_sync\"}"
                )
            }
        }
    }

    private fun isEligibleFinancialNotification(pkg: String, fullText: String): Boolean {
        val lowerPkg = pkg.lowercase()
        val lowerText = fullText.lowercase()

        val nonFinancial = listOf(
            "moodle", "canvas", "blackboard", "classroom", "whatsapp", "telegram",
            "discord", "slack", "teams", "skype", "gmail", "outlook", "mail",
            "instagram", "facebook", "twitter", "tiktok", "youtube", "spotify", "netflix"
        )
        for (item in nonFinancial) {
            if (lowerPkg.contains(item)) return false
        }

        val isFinancialPkg = lowerPkg.contains("bank") ||
                lowerPkg.contains("banco") ||
                lowerPkg.contains("banca") ||
                lowerPkg.contains("wallet") ||
                lowerPkg.contains("fintech") ||
                lowerPkg.contains("nequi") ||
                lowerPkg.contains("daviplata") ||
                lowerPkg.contains("nubank") ||
                lowerPkg.contains("bancolombia") ||
                lowerPkg.contains("davivienda")

        if (isFinancialPkg) return true

        val isSms = lowerPkg.contains("messaging") || lowerPkg.contains("sms") || lowerPkg.contains("mms")
        if (isSms && (lowerText.contains("banco") || lowerText.contains("bancolombia") || lowerText.contains("nequi") || lowerText.contains("nu ") || lowerText.contains("tarjeta") || lowerText.contains("cuenta"))) {
            return true
        }

        return false
    }
}
