package com.longyunvpn.app.common

import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.util.concurrent.atomic.AtomicBoolean

class ServiceDelegate<T>(
    private val intent: Intent,
    private val onServiceDisconnected: ((String) -> Unit)? = null,
    private val interfaceCreator: (IBinder) -> T,
) : CoroutineScope by CoroutineScope(SupervisorJob() + Dispatchers.Default) {

    private val _bindingState = AtomicBoolean(false)

    private var _serviceState = MutableStateFlow<Pair<T?, String>?>(null)

    val serviceState: StateFlow<Pair<T?, String>?> = _serviceState
    private var job: Job? = null

    private fun handleBind(data: Pair<IBinder?, String>) {
        data.first?.let {
            _serviceState.value = Pair(interfaceCreator(it), data.second)
        } ?: run {
            _serviceState.value = Pair(null, data.second)
            unbind()
            onServiceDisconnected?.invoke(data.second)
            _bindingState.set(false)
        }
    }

    fun bind() {
        if (_bindingState.compareAndSet(false, true)) {
            job?.cancel()
            job = null
            _serviceState.value = null
            job = launch {
                runCatching {
                    GlobalState.application.bindServiceFlow<IBinder>(intent)
                        .collect { handleBind(it) }
                }.onFailure {
                    GlobalState.log("Service bind failed: $it")
                }
                // Release the latch whatever happened.
                //
                // Without this the flow terminating - which is what
                // bindServiceFlow does once its retries are exhausted - left
                // _bindingState stuck at true with no service behind it. Every
                // later bind() was then a no-op because compareAndSet(false,
                // true) could never succeed again, and every useService sat
                // out its timeout against a delegate that would never recover.
                // The core could not be reached for the rest of the process,
                // no matter how many times the app retried, which is why the
                // affected phones stayed on "Connecting..." until a full
                // restart.
                if (_serviceState.value?.first == null) {
                    _bindingState.set(false)
                }
            }
        }
    }

    suspend inline fun <R> useService(
        timeoutMillis: Long = 5000, crossinline block: suspend (T) -> R
    ): Result<R> {
        return runCatching {
            withTimeout(timeoutMillis) {
                val state = serviceState.filterNotNull().first()
                state.first?.let {
                    withContext(Dispatchers.Default) {
                        block(it)
                    }
                } ?: throw Exception(state.second)
            }
        }
    }

    fun unbind() {
        if (_bindingState.compareAndSet(true, false)) {
            job?.cancel()
            job = null
            _serviceState.value = null
        }
    }
}