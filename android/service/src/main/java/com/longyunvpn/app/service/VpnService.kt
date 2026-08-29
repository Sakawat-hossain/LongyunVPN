package com.longyunvpn.app.service

import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.ProxyInfo
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.RemoteException
import android.util.Log
import androidx.core.content.getSystemService
import com.longyunvpn.app.common.AccessControlMode
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.core.Core
import com.longyunvpn.app.service.models.VpnOptions
import com.longyunvpn.app.service.models.getIpv4RouteAddress
import com.longyunvpn.app.service.models.getIpv6RouteAddress
import com.longyunvpn.app.service.models.toCIDR
import com.longyunvpn.app.service.modules.NetworkObserveModule
import com.longyunvpn.app.service.modules.NotificationModule
import com.longyunvpn.app.service.modules.SuspendModule
import com.longyunvpn.app.service.modules.moduleLoader
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import java.util.concurrent.ConcurrentHashMap
import java.net.InetSocketAddress
import android.net.VpnService as SystemVpnService

class VpnService : SystemVpnService(), IBaseService,
    CoroutineScope by CoroutineScope(Dispatchers.Default) {

    private val self: VpnService
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

    private val connectivity by lazy {
        getSystemService<ConnectivityManager>()
    }
    // Read and written from the core's threads via JNI, once per connection, so
    // a plain HashMap here is a data race — concurrent writes can corrupt it or
    // spin during a resize.
    private val uidPageNameMap = ConcurrentHashMap<Int, String>()

    private fun resolverProcess(
        protocol: Int,
        source: InetSocketAddress,
        target: InetSocketAddress,
        uid: Int,
    ): String {
        val nextUid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectivity?.getConnectionOwnerUid(protocol, source, target) ?: -1
        } else {
            uid
        }
        if (nextUid == -1) {
            return ""
        }
        // firstOrNull, not first: getPackagesForUid returns an empty array for a
        // uid with no packages mapped to it (shared and system uids do this),
        // and first() throws NoSuchElementException there — inside a callback
        // the core invokes for every connection.
        return uidPageNameMap.getOrPut(nextUid) {
            this.packageManager?.getPackagesForUid(nextUid)?.firstOrNull() ?: ""
        }
    }

    val VpnOptions.address
        get(): String = buildString {
            append(IPV4_ADDRESS)
            if (ipv6) {
                append(",")
                append(IPV6_ADDRESS)
            }
        }

    val VpnOptions.dns
        get(): String {
            if (dnsHijacking) {
                return NET_ANY
            }
            return buildString {
                append(DNS)
                if (ipv6) {
                    append(",")
                    append(DNS6)
                }
            }
        }


    override fun onLowMemory() {
        Core.forceGC()
        super.onLowMemory()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): VpnService = this@VpnService

        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            try {
                val isSuccess = super.onTransact(code, data, reply, flags)
                if (!isSuccess) {
                    GlobalState.log("VpnService disconnected")
                    handleDestroy()
                }
                return isSuccess
            } catch (e: RemoteException) {
                GlobalState.log("VpnService onTransact $e")
                return false
            }
        }
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    private fun handleStart(options: VpnOptions) {
        val fd = with(Builder()) {
            val cidr = IPV4_ADDRESS.toCIDR()
            addAddress(cidr.address, cidr.prefixLength)
            Log.d(
                "addAddress", "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
            )
            val routeAddress = options.getIpv4RouteAddress()
            if (routeAddress.isNotEmpty()) {
                try {
                    routeAddress.forEach { i ->
                        Log.d(
                            "addRoute4", "address: ${i.address} prefixLength:${i.prefixLength}"
                        )
                        addRoute(i.address, i.prefixLength)
                    }
                } catch (_: Exception) {
                    addRoute(NET_ANY, 0)
                }
            } else {
                addRoute(NET_ANY, 0)
            }
            if (options.ipv6) {
                try {
                    val cidr = IPV6_ADDRESS.toCIDR()
                    Log.d(
                        "addAddress6", "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                    )
                    addAddress(cidr.address, cidr.prefixLength)
                } catch (_: Exception) {
                    Log.d(
                        "addAddress6", "IPv6 is not supported."
                    )
                }

                try {
                    val routeAddress = options.getIpv6RouteAddress()
                    if (routeAddress.isNotEmpty()) {
                        try {
                            routeAddress.forEach { i ->
                                Log.d(
                                    "addRoute6",
                                    "address: ${i.address} prefixLength:${i.prefixLength}"
                                )
                                addRoute(i.address, i.prefixLength)
                            }
                        } catch (_: Exception) {
                            addRoute("::", 0)
                        }
                    } else {
                        addRoute(NET_ANY6, 0)
                    }
                } catch (_: Exception) {
                    addRoute(NET_ANY6, 0)
                }
            }
            addDnsServer(DNS)
            if (options.ipv6) {
                addDnsServer(DNS6)
            }
            setMtu(9000)
            options.accessControlProps.let { accessControl ->
                if (accessControl.enable) {
                    // Both of these throw NameNotFoundException for a package
                    // that is no longer installed, and start() catches
                    // everything and calls stop() — so a single stale entry in
                    // the app list silently killed the whole tunnel with no
                    // message. Lists outlive installs, and dropping
                    // QUERY_ALL_PACKAGES narrowed what the picker can even show,
                    // so stale entries are expected. Skip them individually
                    // instead of failing the connection.
                    when (accessControl.mode) {
                        AccessControlMode.ACCEPT_SELECTED -> {
                            (accessControl.acceptList + packageName).forEach {
                                try {
                                    addAllowedApplication(it)
                                } catch (_: PackageManager.NameNotFoundException) {
                                    GlobalState.log("Access control: skipping uninstalled $it")
                                }
                            }
                        }

                        AccessControlMode.REJECT_SELECTED -> {
                            (accessControl.rejectList - packageName).forEach {
                                try {
                                    addDisallowedApplication(it)
                                } catch (_: PackageManager.NameNotFoundException) {
                                    GlobalState.log("Access control: skipping uninstalled $it")
                                }
                            }
                        }
                    }
                }
            }
            setSession("LongyunVPN")
            setBlocking(false)
            if (Build.VERSION.SDK_INT >= 29) {
                setMetered(false)
            }
            if (options.allowBypass) {
                allowBypass()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && options.systemProxy) {
                GlobalState.log("Open http proxy")
                setHttpProxy(
                    ProxyInfo.buildDirectProxy(
                        "127.0.0.1", options.port, options.bypassDomain
                    )
                )
            }
            establish()?.detachFd()
                ?: throw NullPointerException("Establish VPN rejected by system")
        }
        Core.startTun(
            fd,
            protect = this::protect,
            resolverProcess = this::resolverProcess,
            options.stack,
            options.address,
            options.dns
        )
    }

    // Every failure here used to end the same way: the exception was discarded,
    // stop() ran, and the caller was told nothing. The app went on showing
    // "Connected" over a tunnel that was never established, so every request
    // died on a timeout with no line in the log to say why. The three ways that
    // happened, all silent:
    //
    //   - establish() returns null. The system refused the interface: another
    //     VPN app holds the slot, consent was revoked, or an OEM ROM denied it.
    //   - State.options is null. handleStart never ran, nothing threw, and the
    //     service reported a clean start with no interface behind it.
    //   - anything the Builder throws, which on a phone with a stale access
    //     control list is routine.
    //
    // Name the reason in the log, then rethrow so the caller can report the
    // failure instead of inventing a success.
    override fun start() {
        try {
            loader.load()
            val options = State.options
                ?: throw IllegalStateException("no VPN options were supplied")
            handleStart(options)
        } catch (e: Exception) {
            GlobalState.log("VpnService start failed: ${e.javaClass.simpleName}: ${e.message}")
            stop()
            throw e
        }
    }

    override fun stop() {
        loader.cancel()
        Core.stopTun()
        stopSelf()
    }

    companion object {
        private const val IPV4_ADDRESS = "172.19.0.1/30"
        private const val IPV6_ADDRESS = "fdfe:dcba:9876::1/126"
        private const val DNS = "172.19.0.2"
        private const val DNS6 = "fdfe:dcba:9876::2"
        private const val NET_ANY = "0.0.0.0"
        private const val NET_ANY6 = "::"
    }
}