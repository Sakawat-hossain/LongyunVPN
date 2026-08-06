package com.longyunvpn.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.longyunvpn.app.common.GlobalState
import org.json.JSONObject

/**
 * Handles device boot.
 *
 * IMPORTANT — Android background-start restrictions:
 *  - Android 8+ (API 26) blocks background service starts.
 *  - Android 10+ (API 29) blocks background activity starts.
 *  - Android 12+ (API 31) blocks starting a foreground service from the
 *    background, and a VpnService is NOT on the exemption list.
 *
 * So this receiver must NEVER start the VPN directly. It only does safe work:
 * it reads the user's auto-connect preference and, if enabled, posts a one-tap
 * "reconnect" notification. Tapping it opens the app in the foreground, where
 * starting the VPN is permitted and the app's normal auto-connect flow runs.
 *
 * Users who want a true start-on-boot should enable Android's Always-on VPN
 * (Settings → Network & internet → VPN → LongyunVPN → Always-on), which the OS
 * itself launches at boot on every supported version. The app links there via
 * AppPlugin.openVpnSettings().
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        // Cover the standard boot action plus the OEM quick-boot variants used
        // by some Transsion/HTC devices.
        val isBoot = action == Intent.ACTION_BOOT_COMPLETED ||
                action == "android.intent.action.QUICKBOOT_POWERON" ||
                action == "com.htc.intent.action.QUICKBOOT_POWERON"
        if (!isBoot) return

        if (!isAutoConnectEnabled(context)) {
            GlobalState.log("Boot: auto-connect disabled, nothing to do")
            return
        }
        GlobalState.log("Boot: auto-connect enabled, showing reconnect prompt")
        showReconnectNotification(context)
    }

    // Reads appSettingProps.autoRun from the Flutter-persisted config blob.
    // Kept defensive: any parse/read failure means "don't prompt".
    private fun isAutoConnectEnabled(context: Context): Boolean {
        return try {
            val sp = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val configString = sp.getString("flutter.config", null) ?: return false
            JSONObject(configString)
                .optJSONObject("appSettingProps")
                ?.optBoolean("autoRun", false) == true
        } catch (_: Exception) {
            false
        }
    }

    private fun showReconnectNotification(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        // Notification channels are required on API 26+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(RECONNECT_CHANNEL) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(
                    RECONNECT_CHANNEL,
                    "Reconnect",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Prompts to reconnect the VPN after a restart"
                }
            )
        }

        // Opening the launcher activity is a foreground, user-initiated start —
        // allowed on every version — after which the app's auto-connect logic
        // (and VPN-consent UI, if ever needed) can run normally.
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            ?: return

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val profileName = try {
            GlobalState.application.sharedState.currentProfileName
        } catch (_: Exception) {
            "LongyunVPN"
        }

        val notification = NotificationCompat.Builder(context, RECONNECT_CHANNEL)
            .setSmallIcon(R.drawable.ic_tile)
            .setContentTitle("LongyunVPN")
            .setContentText("Tap to reconnect $profileName")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()

        // On Android 13+ this silently no-ops if POST_NOTIFICATIONS was never
        // granted — an acceptable graceful fallback (we can't request a runtime
        // permission from a receiver, and we must not start anything ourselves).
        try {
            manager.notify(RECONNECT_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
        }
    }

    companion object {
        private const val RECONNECT_CHANNEL = "reconnect"

        // Distinct from the foreground-service notification (GlobalState.NOTIFICATION_ID = 1).
        private const val RECONNECT_NOTIFICATION_ID = 2
    }
}
