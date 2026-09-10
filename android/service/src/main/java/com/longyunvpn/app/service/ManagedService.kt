package com.longyunvpn.app.service

import android.app.Service
import com.longyunvpn.app.common.BroadcastAction
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.common.sendBroadcast

interface ManagedService {
    fun start()

    fun stop()
}

internal fun Service.notifyVpnStartRequested() {
    GlobalState.log("VPN start requested")
    BroadcastAction.VPN_START_REQUESTED.sendBroadcast()
}

internal fun Service.notifyVpnRevoked() {
    GlobalState.log("VPN permission revoked")
    BroadcastAction.VPN_REVOKED.sendBroadcast()
}
