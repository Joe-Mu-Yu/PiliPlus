package com.aritxonly.hyperpiliplus

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class CoupleSpaceNotifications(
    private val activity: Activity,
    engine: FlutterEngine,
) {
    companion object {
        private const val CHANNEL_NAME = "hyper_piliplus/couple_space_notifications"
        private const val NOTIFICATION_CHANNEL_ID = "couple_space_messages"
    }

    private val manager = activity.getSystemService(NotificationManager::class.java)
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val title = call.argument<String>("title")
            val body = call.argument<String>("body")
            val eventId = call.argument<String>("id")
            if (title.isNullOrBlank() || body.isNullOrBlank() || eventId.isNullOrBlank()) {
                result.error("arguments", "Notification id, title, and body are required", null)
                return@setMethodCallHandler
            }
            if (
                ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                result.success(false)
                return@setMethodCallHandler
            }
            createNotificationChannel()
            manager.notify(eventId.hashCode(), buildNotification(title, body))
            result.success(true)
        }
    }

    private fun createNotificationChannel() {
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "小窝消息",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "小窝中对方发布的照片、心语和评论"
            },
        )
    }

    private fun buildNotification(title: String, body: String): Notification {
        val intent = Intent(activity, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            activity,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(activity, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
