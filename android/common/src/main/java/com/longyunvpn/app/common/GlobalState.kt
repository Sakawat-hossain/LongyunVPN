package com.longyunvpn.app.common


import android.app.Application
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

object GlobalState : CoroutineScope by CoroutineScope(Dispatchers.Default) {

    // Internal channel id. Renamed off the pre-rebrand "FlClash" id as part of
    // the branding migration. Android channels are immutable once created, so
    // this is a one-time reset for anyone upgrading: they get a fresh channel at
    // default importance, and the old "FlClash" entry lingers in the system
    // notification settings until the app is reinstalled. New installs are
    // unaffected. Do not rename again without the same consideration.
    const val NOTIFICATION_CHANNEL = "LongyunVPN"

    const val NOTIFICATION_ID = 1

    val packageName: String
        get() = application.packageName

    val RECEIVE_BROADCASTS_PERMISSIONS: String
        get() = "${packageName}.permission.RECEIVE_BROADCASTS"


    private var _application: Application? = null

    val application: Application
        get() = _application!!


    fun log(text: String) {
        Log.d("[LongyunVPN]", text)
    }

    fun init(application: Application) {
        _application = application
    }

    // Crash reporting (Firebase Crashlytics) was removed for the LongyunVPN
    // release so the app ships no third-party telemetry. Kept as a no-op so the
    // existing callers (State / Service / RemoteService) continue to compile.
    fun setCrashlytics(enable: Boolean) {
    }
}