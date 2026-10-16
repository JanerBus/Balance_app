package com.example.personal_finance

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {

    const val CHANNEL_BANK_SYNC = "channel_bank_sync"
    const val CHANNEL_BUDGETS = "channel_budgets"
    const val CHANNEL_DEBTS = "channel_debts"
    const val CHANNEL_RECURRING = "channel_recurring"
    const val CHANNEL_DAILY = "channel_daily_reminder"

    private var channelsCreated = false

    fun createChannels(context: Context) {
        if (channelsCreated || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val channels = listOf(
            NotificationChannel(
                CHANNEL_BANK_SYNC,
                "Transacciones Bancarias Detectadas",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas inmediatas al detectar compras, pagos o transferencias bancarias"
                enableVibration(true)
                setShowBadge(true)
            },
            NotificationChannel(
                CHANNEL_BUDGETS,
                "Alertas de Presupuestos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Avisos preventivos al alcanzar el 80% o exceder el presupuesto de una categoría"
                enableVibration(true)
                setShowBadge(true)
            },
            NotificationChannel(
                CHANNEL_DEBTS,
                "Recordatorios de Deudas y Préstamos",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Recordatorios de fechas límites de cobros y pagos de deudas"
                setShowBadge(true)
            },
            NotificationChannel(
                CHANNEL_RECURRING,
                "Suscripciones y Gastos Recurrentes",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Avisos previos al cobro de suscripciones o servicios fijos"
                setShowBadge(true)
            },
            NotificationChannel(
                CHANNEL_DAILY,
                "Recordatorio Diario de Balance",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Recordatorio nocturno para mantener tus finanzas y gastos al día"
                setShowBadge(true)
            }
        )

        for (channel in channels) {
            manager.createNotificationChannel(channel)
        }

        channelsCreated = true
    }

    fun showNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        channelId: String = CHANNEL_BANK_SYNC,
        payload: String? = null
    ) {
        createChannels(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (payload != null) {
                putExtra("payload", payload)
            }
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            pendingIntentFlags
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(
                if (channelId == CHANNEL_BANK_SYNC || channelId == CHANNEL_BUDGETS)
                    NotificationCompat.PRIORITY_HIGH
                else
                    NotificationCompat.PRIORITY_DEFAULT
            )
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(id, builder.build())
    }

    fun cancelNotification(context: Context, id: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(id)
    }

    fun areNotificationsEnabled(context: Context): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }
}
