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

    // Broadcast receiver to handle stop signals from the Foreground Service notification
    private val stopReceiver =
            object : android.content.BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.castnow.app.STOP_SESSION") {
                        Log.d(
                                "CastNow",
                                "MainActivity: Stop broadcast received. Sycing with Flutter."
                        )
                        Handler(Looper.getMainLooper()).post {
                            methodChannel?.invokeMethod("onStopPressed", null)
                        }
                    }
                }
            }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register DisplayListener to detect when the virtual display is stopped by the system
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(this, Handler(Looper.getMainLooper()))

        // Register receiver for Android 14 compatibility
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
                    val type = call.argument<String>("type") ?: "mediaProjection"
                    val serviceIntent =
                            Intent(this, MediaProjectionService::class.java).apply {
                                putExtra("type", type)
                            }
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Detect if this is the media projection permission result
        // The flutter_webrtc plugin often doesn't give us the request code,
        // but the system resultCode will be OK if granted.
        // On Android 14, if we just granted permission, we should immediately 'upgrade'
        // our foreground service so that the capturer (which is about to start)
        // finds the service in the correct state.

        if (resultCode == RESULT_OK && Build.VERSION.SDK_INT >= 34) {
            Log.d(
                    "CastNow",
                    "MainActivity: Permission granted (OK). Upgrading service to mediaProjection."
            )
            val upgradeIntent =
                    Intent(this, MediaProjectionService::class.java).apply {
                        putExtra("type", "mediaProjection")
                    }
            startForegroundService(upgradeIntent)
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
            // Logic: If a virtual display named "ScreenCapture" turns OFF (state 1),
            // it usually means the system has paused or stopped the projection.
            if (display.state == 1 && display.name.contains("ScreenCapture")) {
                Log.d("CastNow", "Virtual display ($displayId) turned OFF. Stopping session.")
                runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
            }
        }
    }

    override fun onDisplayRemoved(displayId: Int) {
        Log.d("CastNow", "Display Removed: $displayId. Notifying Flutter.")
        runOnUiThread { methodChannel?.invokeMethod("onStopPressed", null) }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(stopReceiver)
        } catch (e: Exception) {}
        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.unregisterDisplayListener(this)
    }
}
