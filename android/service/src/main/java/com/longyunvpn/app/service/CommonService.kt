package com.longyunvpn.app.service

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.core.Core
import com.longyunvpn.app.service.modules.NetworkObserveModule
import com.longyunvpn.app.service.modules.NotificationModule
import com.longyunvpn.app.service.modules.SuspendModule
import com.longyunvpn.app.service.modules.moduleLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

class CommonService : Service(), IBaseService,
    CoroutineScope by CoroutineScope(Dispatchers.Default) {

    private val self: CommonService
        get() = this

    private val loader = moduleLoader {
        install(NetworkObserveModule(self))
        install(NotificationModule(self))
        install(SuspendModule(self))
    }

    override fun onCreate() {
        super.onCreate()
        handleCreate()
    }

    override fun onDestroy() {
        handleDestroy()
        super.onDestroy()
    }

    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): CommonService = this@CommonService
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    // Rethrow rather than swallow, for the same reason as VpnService.start:
    // a module that fails to load leaves nothing running, and reporting that as
    // a successful start is what produces a "connected" app with no tunnel.
    override fun start() {
        try {
            loader.load()
        } catch (e: Exception) {
            GlobalState.log("CommonService start failed: ${e.javaClass.simpleName}: ${e.message}")
            stop()
            throw e
        }
    }

    override fun stop() {
        loader.cancel()
        stopSelf()
    }
}