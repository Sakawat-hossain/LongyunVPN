package com.longyunvpn.app

import android.app.Application
import android.content.Context
import com.longyunvpn.app.common.GlobalState

class Application : Application() {

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
