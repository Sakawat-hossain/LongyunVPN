package com.longyunvpn.app

import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.common.ServiceDelegate
import com.longyunvpn.app.common.formatString
import com.longyunvpn.app.common.intent
import com.longyunvpn.app.service.IAckInterface
import com.longyunvpn.app.service.ICallbackInterface
import com.longyunvpn.app.service.IEventInterface
import com.longyunvpn.app.service.IRemoteInterface
import com.longyunvpn.app.service.IResultInterface
import com.longyunvpn.app.service.IVoidInterface
import com.longyunvpn.app.service.RemoteService
import com.longyunvpn.app.service.models.NotificationParams
import com.longyunvpn.app.service.models.VpnOptions
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

object Service {
    private val delegate by lazy {
        ServiceDelegate<IRemoteInterface>(
            RemoteService::class.intent, ::handleServiceDisconnected
        ) {
            IRemoteInterface.Stub.asInterface(it)
        }
    }

    var onServiceDisconnected: ((String) -> Unit)? = null

    private fun handleServiceDisconnected(message: String) {
        onServiceDisconnected?.let {
            it(message)
        }
    }

    fun bind() {
        delegate.bind()
    }

    fun unbind() {
        delegate.unbind()
    }

    suspend fun invokeAction(data: String, cb: ((result: String) -> Unit)?): Result<Unit> {
        val res = mutableListOf<ByteArray>()
        return delegate.useService {
            it.invokeAction(
                data, object : ICallbackInterface.Stub() {
                    override fun onResult(
                        result: ByteArray?, isSuccess: Boolean, ack: IAckInterface?
                    ) {
                        res.add(result ?: byteArrayOf())
                        ack?.onAck()
                        if (isSuccess) {
                            cb?.let { cb ->
                                cb(res.formatString())
                            }
                        }
                    }
                })
        }
    }

    suspend fun quickSetup(
        initParamsString: String,
        setupParamsString: String,
        onStarted: (() -> Unit)?,
        onResult: ((result: String) -> Unit)?,
    ): Result<Unit> {
        val res = mutableListOf<ByteArray>()
        return delegate.useService {
            it.quickSetup(
                initParamsString,
                setupParamsString,
                object : ICallbackInterface.Stub() {
                    override fun onResult(
                        result: ByteArray?, isSuccess: Boolean, ack: IAckInterface?
                    ) {
                        res.add(result ?: byteArrayOf())
                        ack?.onAck()
                        if (isSuccess) {
                            onResult?.let { cb ->
                                cb(res.formatString())
                            }
                        }
                    }
                },
                object : IVoidInterface.Stub() {
                    override fun invoke() {
                        onStarted?.let { onStarted ->
                            onStarted()
                        }
                    }
                }
            )
        }
    }

    suspend fun setEventListener(
        cb: ((result: String?) -> Unit)?
    ): Result<Unit> {
        // Binder delivers callbacks on a thread pool, and events for different
        // ids can land concurrently, so this map is touched from several
        // threads at once — a plain HashMap can corrupt or spin on resize here.
        val results = ConcurrentHashMap<String, MutableList<ByteArray>>()
        return delegate.useService {
            it.setEventListener(
                when (cb != null) {
                    true -> object : IEventInterface.Stub() {
                        override fun onEvent(
                            id: String, data: ByteArray?, isSuccess: Boolean, ack: IAckInterface?
                        ) {
                            // computeIfAbsent, not a get-then-put: the latter is
                            // two operations and two threads can both see the
                            // key missing, so one event's chunks get dropped on
                            // the floor when the second list replaces the first.
                            val chunks = results.computeIfAbsent(id) {
                                mutableListOf()
                            }
                            chunks.add(data ?: byteArrayOf())
                            ack?.onAck()
                            if (isSuccess) {
                                // Remove first, then format what we removed —
                                // reading through the map after removing risks
                                // handing back null for an event we did receive.
                                results.remove(id)
                                cb(chunks.formatString())
                            }
                        }
                    }

                    false -> null
                })
        }
    }

    suspend fun updateNotificationParams(
        params: NotificationParams
    ): Result<Unit> {
        return delegate.useService {
            it.updateNotificationParams(params)
        }
    }

    suspend fun setCrashlytics(
        enable: Boolean
    ): Result<Unit> {
        return delegate.useService {
            it.setCrashlytics(enable)
        }
    }

    private suspend fun awaitIResultInterface(
        block: (IResultInterface) -> Unit
    ): Long = suspendCancellableCoroutine { continuation ->
        val callback = object : IResultInterface.Stub() {
            override fun onResult(time: Long) {
                if (continuation.isActive) {
                    continuation.resume(time)
                }
            }
        }

        try {
            block(callback)
        } catch (e: Exception) {
            GlobalState.log("awaitIResultInterface $e")
            if (continuation.isActive) {
                continuation.resumeWithException(e)
            }
        }
    }


    suspend fun startService(options: VpnOptions, runTime: Long): Long {
        return delegate.useService {
            awaitIResultInterface { callback ->
                it.startService(options, runTime, callback)
            }
        }.getOrNull() ?: 0L
    }

    suspend fun stopService(): Long {
        return delegate.useService {
            awaitIResultInterface { callback ->
                it.stopService(callback)
            }
        }.getOrNull() ?: 0L
    }

    suspend fun getRunTime(): Long {
        return delegate.useService {
            it.runTime
        }.getOrNull() ?: 0L
    }
}