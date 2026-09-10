package com.longyunvpn.app.plugins

import com.longyunvpn.app.ServiceController
import com.longyunvpn.app.ServiceState
import com.longyunvpn.app.common.Components
import com.longyunvpn.app.models.SharedState
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class ServicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var scope: CoroutineScope
    private val gson = Gson()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        channel = MethodChannel(binding.binaryMessenger, "${Components.PACKAGE_NAME}/service")
        channel.setMethodCallHandler(this)
        ServiceController.setServiceLostListener(::onServiceLost)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Cleared before the scope goes, so a loss reported during teardown
        // cannot launch onto a cancelled scope.
        ServiceController.setServiceLostListener(null)
        scope.cancel()
        ServiceController.setEventListener(null)
    }

    override fun onMethodCall(call: MethodCall, rawResult: MethodChannel.Result) {
        // Most handlers below reply from a scope worker on Dispatchers.Default,
        // but a MethodChannel.Result has to be answered on the platform thread.
        // Wrapping once here covers every branch, including notImplemented.
        val result = MainThreadResult(rawResult)
        when (call.method) {
            "init" -> initialize(result)
            "shutdown" -> shutdown(result)
            // Named to match the Dart side and the core's exported entry point.
            "invokeAction" -> invokeAction(call, result)
            "getRunTime" -> getRunTime(result)
            "syncState" -> syncState(call, result)
            "start" -> start(result)
            "stop" -> stop(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(result: MethodChannel.Result) {
        ServiceController.setEventListener(::sendEvent)
            .onSuccess { result.success("") }
            .onFailure { error -> result.success(error.message.orEmpty()) }
    }

    private fun shutdown(result: MethodChannel.Result) {
        scope.launch {
            ServiceController.unbind()
            result.success(true)
        }
    }

    private fun invokeAction(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as? String
        if (data == null) {
            result.error("INVALID_ARGUMENT", "Method call payload must be a string", null)
            return
        }
        scope.launch {
            ServiceController.invokeAction(data) { response ->
                result.success(response)
            }.onFailure { error ->
                result.error("CORE_ERROR", error.message, null)
            }
        }
    }

    private fun getRunTime(result: MethodChannel.Result) {
        scope.launch {
            result.success(ServiceState.refresh())
        }
    }

    private fun syncState(call: MethodCall, result: MethodChannel.Result) {
        val data = call.arguments as? String
        val state = runCatching {
            gson.fromJson(data, SharedState::class.java)
        }.getOrNull()
        if (state == null) {
            result.success("Invalid shared state")
            return
        }
        scope.launch {
            ServiceState.syncSharedState(state)
            result.success("")
        }
    }

    private fun start(result: MethodChannel.Result) {
        ServiceState.requestStart()
        result.success(true)
    }

    private fun stop(result: MethodChannel.Result) {
        ServiceState.requestStop()
        result.success(true)
    }

    private fun sendEvent(value: String?) {
        scope.launch(Dispatchers.Main) {
            channel.invokeMethod("event", value)
        }
    }

    /**
     * Reports a running service that was lost without anyone asking it to stop:
     * an OEM task killer, the system reclaiming it, a crash inside it.
     *
     * The state machine records the loss on its own, but that only updates
     * native state - Dart would carry on showing a live connection over a dead
     * tunnel, and its reconnect logic, which listens for "crash", would never
     * run. A user-requested stop never reaches here: stopping clears the binding
     * first, so the disconnect it causes is recognised as stale and dropped.
     */
    private fun onServiceLost(message: String) {
        scope.launch(Dispatchers.Main) {
            channel.invokeMethod("crash", message)
        }
    }
}
