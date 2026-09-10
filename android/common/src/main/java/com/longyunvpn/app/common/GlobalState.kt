package com.longyunvpn.app.common

import android.app.ActivityManager
import android.app.Application
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

// SupervisorJob so one failed child cannot cancel the scope, and with it every
// later lifecycle job launched on it for the rest of the process.
object GlobalState : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {

    // Internal channel id, set during the rebrand. Android channels are
    // immutable once created, so changing this is a one-time reset for everyone
    // upgrading: they get a fresh channel at default importance, and the old
    // entry lingers in the system notification settings until reinstall. Do not
    // rename it again without the same consideration.
    const val NOTIFICATION_CHANNEL = "LongyunVPN"

    const val NOTIFICATION_ID = 1

    private const val ANY_PID = 0

    // getHistoricalProcessExitReasons treats a maxNum of 0 as "all records".
    private const val EVERY_EXIT_RECORD = 0

    val packageName: String
        get() = application.packageName

    val receiveBroadcastPermission: String
        get() = "$packageName.permission.RECEIVE_BROADCASTS"

    val application: Application
        get() = checkNotNull(appInstance) { "GlobalState is not initialized" }

    @Volatile
    private var appInstance: Application? = null

    fun init(application: Application) {
        appInstance = application
    }

    fun log(text: String) {
        Log.d("[LongyunVPN]", text)
    }

    // Crash-reporting consent belongs to the Dart side (FirebaseService), which
    // turns Crashlytics on only once the user has agreed. Calling the native SDK
    // here as well would give collection a second, independent switch - one that
    // runs before consent is known. Kept as a no-op so callers still compile.
    fun setCrashlytics(enable: Boolean) {
    }

    /**
     * Why Android last ended this app's process, or null below API 30.
     *
     * This is the record that explains a phone that "just stopped" connecting -
     * killed for memory, an ANR, a native crash, or an OEM battery manager -
     * which no app-side logging can see, because the app was not running to
     * write it.
     *
     * Every record is read and the main process picked out, so a sub-process
     * stuck in a crash loop cannot push the one that matters out of the history.
     */
    fun lastExitInfo(): Map<String, Any?>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val manager = application.getSystemService(ActivityManager::class.java) ?: return null
        val info = runCatching {
            manager.getHistoricalProcessExitReasons(
                application.packageName,
                ANY_PID,
                EVERY_EXIT_RECORD,
            )
        }.getOrNull()?.firstOrNull { it.processName == application.packageName } ?: return null
        return mapOf(
            "reason" to info.reason,
            "timestamp" to info.timestamp,
            "description" to info.description,
        )
    }
}
