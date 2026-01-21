package com.castnow.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class MediaProjectionService : Service() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.d("CastNow", "Service onStartCommand: action=$action")

        if (action == "ACTION_STOP_SERVICE") {
            Log.d("CastNow", "Service: User clicked STOP in notification. Self-stopping.")
            stopSelf()
            return START_NOT_STICKY
        }

        val channelId = "screen_share"
        createNotificationChannel(channelId)

        val stopIntent =
                Intent(this, MediaProjectionService::class.java).apply {
                    setAction("ACTION_STOP_SERVICE")
                }
        val stopPendingIntent =
                PendingIntent.getService(
                        this,
                        0,
                        stopIntent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )

        val notification =
                NotificationCompat.Builder(this, channelId)
                        .setContentTitle("屏幕共享激活中")
                        .setContentText("CastNow 正在运行前台服务")
                        .setSmallIcon(
                                applicationContext.resources.getIdentifier(
                                        "ic_launcher",
                                        "mipmap",
                                        packageName
                                )
                        )
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .setOngoing(true)
                        .addAction(
                                android.R.drawable.ic_menu_close_clear_cancel,
                                "STOP",
                                stopPendingIntent
                        )
                        .build()

        // Android 14 requirements
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                    1002,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(1002, notification)
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel(channelId: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    channelId,
                                    "Screen Sharing Service",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply { description = "用于维持投屏功能的前台通知" }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        Log.d("CastNow", "MediaProjectionService destroying...")
        super.onDestroy()
        val intent = Intent("com.castnow.app.STOP_SESSION")
        intent.setPackage(packageName)
        sendBroadcast(intent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
