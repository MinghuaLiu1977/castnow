package com.castnow.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), DisplayManager.DisplayListener {

    private val PROJECTION_CHANNEL = "media_projection"
    private var methodChannel: MethodChannel? = null

    // Defines a broadcast receiver for safety, though DisplayListener is primary
    private val stopReceiver =
            object : android.content.BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.castnow.app.STOP_SESSION") {
                        Log.d(
                                "CastNow",
                                "MainActivity: Received STOP_SESSION broadcast. Notifying Flutter."
                        )
                        // Ensure we are on main thread
                        Handler(Looper.getMainLooper()).post {
                            methodChannel?.invokeMethod("onStopPressed", null)
                        }
                    }
                }
            }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("CastNow", "MainActivity: onCreate")

        // Register DisplayListener to detect screen share termination
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(this, Handler(Looper.getMainLooper()))
        Log.d("CastNow", "MainActivity: DisplayListener registered")

        // Register receiver for Android 14 compat (exported)
        val filter = IntentFilter("com.castnow.app.STOP_SESSION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(stopReceiver, filter)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROJECTION_CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMediaProjectionService" -> {
                    val serviceIntent = Intent(this, MediaProjectionService::class.java)
                    startForegroundService(serviceIntent)
                    result.success(null)
                }
                "stopMediaProjectionService" -> {
                    val serviceIntent = Intent(this, MediaProjectionService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- DisplayListener Implementation ---
    override fun onDisplayAdded(displayId: Int) {
        Log.d("CastNow", "Display Added: $displayId")
    }

    override fun onDisplayChanged(displayId: Int) {
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(displayId)
        if (display != null) {
            Log.d(
                    "CastNow",
                    "Display Changed: $displayId, State: ${display.state}, NAME: ${display.name}"
            )
            // If display turns OFF (1), it effectively means the screen share is stopped/paused by
            // system
            // Log shows: Display Changed: 65, State: 1, NAME: WebRTC_ScreenCapture
            // Value 1 is STATE_OFF
            if (display.state == 1 && display.name.contains("ScreenCapture")) {
                Log.d(
                        "CastNow",
                        "Display $displayId (${display.name}) turned OFF. Triggering stop."
                )
                runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
            }
        } else {
            Log.d("CastNow", "Display Changed: $displayId but is null")
        }
    }

    override fun onDisplayRemoved(displayId: Int) {
        Log.d("CastNow", "Display Removed: $displayId. Checking if it's the screen share...")
        // If a display is removed, it's highly likely the screen share stopping.
        // We notify Flutter to stop the session.
        runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(stopReceiver)
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(this)
        Log.d("CastNow", "MainActivity: onDestroy")
    }
}
