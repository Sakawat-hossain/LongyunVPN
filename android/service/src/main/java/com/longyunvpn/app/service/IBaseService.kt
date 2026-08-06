package com.longyunvpn.app.service

import com.longyunvpn.app.common.BroadcastAction
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.common.sendBroadcast

interface IBaseService {
    fun handleCreate() {
        GlobalState.log("Service create")
        BroadcastAction.SERVICE_CREATED.sendBroadcast()
    }

    fun handleDestroy() {
        GlobalState.log("Service destroy")
        BroadcastAction.SERVICE_DESTROYED.sendBroadcast()
    }

    fun start()

    fun stop()
}