package com.castnow.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class MediaProjectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var upgradeRunnable: Runnable? = null
    private var currentNotificationId = 1002

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == "ACTION_STOP_SERVICE") {
            Log.d("CastNow", "Service: Manual stop requested via notification.")
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

        val iconId =
                applicationContext.resources.getIdentifier("ic_launcher", "mipmap", packageName)
        val notification =
                NotificationCompat.Builder(this, channelId)
                        .setContentTitle("Screen Sharing Active")
                        .setContentText("CastNow is broadcasting your screen")
                        .setSmallIcon(
                                if (iconId != 0) iconId else android.R.drawable.ic_dialog_info
                        )
                        .setPriority(NotificationCompat.PRIORITY_LOW)
                        .setOngoing(true)
                        .addAction(
                                android.R.drawable.ic_menu_close_clear_cancel,
                                "STOP",
                                stopPendingIntent
                        )
                        .build()

        // Requirements for Android 10+ (Q)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val typeStr = intent?.getStringExtra("type")
            Log.d("CastNow", "MediaProjectionService: Received start request for type: $typeStr")

            if (typeStr == "mediaProjection" && Build.VERSION.SDK_INT >= 34) {
                Log.d(
                        "CastNow",
                        "MediaProjectionService: Android 14 detected. Starting as bridge first."
                )
                startWithBridge(notification)
            } else {
                val type =
                        when (typeStr) {
                            "mediaProjection" ->
                                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                            "dataSync" -> ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                            else -> ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                        }
                startForeground(currentNotificationId, notification, type)
            }
        } else {
            startForeground(currentNotificationId, notification)
        }

        return START_NOT_STICKY
    }

    private fun startWithBridge(notification: android.app.Notification) {
        // Step 1: Start as dataSync (allowed without dialog)
        try {
            Log.d("CastNow", "MediaProjectionService: Initializing bridge as dataSync...")
            startForeground(
                    currentNotificationId,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )

            // Step 2: Start polling for upgrade
            startPollingUpgrade(notification)
        } catch (e: Exception) {
            Log.e("CastNow", "MediaProjectionService: Failed to start bridge: ${e.message}")
        }
    }

    private fun startPollingUpgrade(notification: android.app.Notification) {
        upgradeRunnable?.let { handler.removeCallbacks(it) }

        upgradeRunnable =
                object : Runnable {
                    override fun run() {
                        if (Build.VERSION.SDK_INT >= 34) {
                            try {
                                Log.d(
                                        "CastNow",
                                        "MediaProjectionService: Attempting upgrade to mediaProjection..."
                                )
                                startForeground(
                                        currentNotificationId,
                                        notification,
                                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                                )
                                Log.d(
                                        "CastNow",
                                        "MediaProjectionService: UPGRADE SUCCESSFUL! Polling stopped."
                                )
                                upgradeRunnable = null
                            } catch (e: SecurityException) {
                                Log.d(
                                        "CastNow",
                                        "MediaProjectionService: Upgrade failed (no permission yet), retrying in 500ms..."
                                )
                                handler.postDelayed(this, 500)
                            } catch (e: Exception) {
                                Log.e(
                                        "CastNow",
                                        "MediaProjectionService: Unexpected error during upgrade: ${e.message}"
                                )
                                handler.postDelayed(this, 1000)
                            }
                        }
                    }
                }
        handler.post(upgradeRunnable!!)
    }

    private fun createNotificationChannel(channelId: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    channelId,
                                    "Screen Sharing Service",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply { description = "Enables background screen capture for CastNow" }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        upgradeRunnable?.let { handler.removeCallbacks(it) }
        Log.d("CastNow", "MediaProjectionService: onDestroy. Broadcasting stop signal.")

        // Signal MainActivity that the service is shutting down
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
