package com.longyunvpn.app.core

import androidx.annotation.Keep

@Keep
interface InvokeInterface {
    fun onResult(result: String?)
}