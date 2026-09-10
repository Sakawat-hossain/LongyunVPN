package com.longyunvpn.app.service.modules

import android.app.Service
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkCapabilities.TRANSPORT_SATELLITE
import android.net.NetworkCapabilities.TRANSPORT_USB
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.getSystemService
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.core.Core
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap

private data class NetworkInfo(
    @Volatile var losingUntilMillis: Long = 0,
    @Volatile var dnsList: List<InetAddress> = emptyList(),
) {
    val priorityPenalty: Int
        get() = if (losingUntilMillis > System.currentTimeMillis()) 10 else 0
}

internal class NetworkObserveModule(private val service: Service) : ServiceModule {

    private val networkInfos = ConcurrentHashMap<Network, NetworkInfo>()
    private val connectivity by lazy {
        service.getSystemService<ConnectivityManager>()
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentDnsList = listOf<String>()
    private var currentUnderlyingNetwork: Network? = null

    private val request = NetworkRequest.Builder().apply {
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
        addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            addCapability(NetworkCapabilities.NET_CAPABILITY_FOREGROUND)
        }
        addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
    }.build()

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            networkInfos[network] = NetworkInfo()
            updateNetworks()
        }

        override fun onLosing(network: Network, maxMsToLive: Int) {
            val info = networkInfos[network] ?: return
            info.losingUntilMillis = System.currentTimeMillis() + maxMsToLive
            updateNetworks()
            if (maxMsToLive > 0) {
                mainHandler.postDelayed({
                    if (networkInfos.containsKey(network)) {
                        updateNetworks()
                    }
                }, maxMsToLive.toLong() + 50)
            }
        }

        override fun onLost(network: Network) {
            networkInfos.remove(network)
            updateNetworks()
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
            networkInfos[network]?.dnsList = linkProperties.dnsServers
            updateNetworks()
        }
    }

    override fun start() {
        updateNetworks()
        connectivity?.registerNetworkCallback(request, callback)
    }

    private fun networkPriority(entry: Map.Entry<Network, NetworkInfo>): Int {
        val capabilities = connectivity?.getNetworkCapabilities(entry.key)
        return when {
            capabilities == null -> 100
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> 90
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> 1
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                capabilities.hasTransport(TRANSPORT_USB) -> 2

            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH) -> 3
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 4
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM &&
                capabilities.hasTransport(TRANSPORT_SATELLITE) -> 5

            else -> 20
        } + entry.value.priorityPenalty
    }

    /**
     * Ranks the tracked networks once and applies the winner twice: as the
     * network the tunnel runs over, and as the source of the core's DNS
     * servers. One ranking for both, so they cannot disagree about which
     * network is live.
     */
    @Synchronized
    private fun updateNetworks() {
        val best = networkInfos.entries.minByOrNull(::networkPriority)
        // Ahead of the DNS early-return below: a handoff between two networks
        // with the same resolvers changes nothing there, and would otherwise
        // never move the tunnel.
        updateUnderlyingNetwork(best?.key)
        val dnsList = best?.value?.dnsList
            .orEmpty()
            .map { address -> address.asSocketAddressText(DNS_PORT) }
            .distinct()
        if (dnsList == currentDnsList) {
            return
        }
        currentDnsList = dnsList
        Core.updateDNS(dnsList.joinToString(","))
    }

    /**
     * Tells Android which physical network carries the tunnel.
     *
     * Without it the VPN goes on reporting the network it came up on, so after a
     * Wi-Fi to mobile handoff the tunnel sits on a network that has gone and
     * traffic stalls until something forces a reconnect - speed collapsing, or
     * every server timing out, until the user toggles the VPN. Null means
     * "follow the system default", the right fallback while nothing is tracked,
     * including mid-handoff. VpnService only; a no-op in proxy mode.
     *
     * The system is touched only when the winner changes, because link-property
     * callbacks arrive far more often than handoffs do.
     *
     * Ours, not upstream's. It was lost once already when this module was
     * replaced wholesale; keep it through any future sync.
     */
    private fun updateUnderlyingNetwork(best: Network?) {
        val vpn = service as? VpnService ?: return
        if (best == currentUnderlyingNetwork) {
            return
        }
        currentUnderlyingNetwork = best
        vpn.setUnderlyingNetworks(best?.let { arrayOf(it) })
        GlobalState.log("Underlying network -> ${transportName(best)}")
    }

    private fun transportName(network: Network?): String {
        if (network == null) return "system default"
        val capabilities = connectivity?.getNetworkCapabilities(network) ?: return "unknown"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
    }

    override fun stop() {
        mainHandler.removeCallbacksAndMessages(null)
        try {
            connectivity?.unregisterNetworkCallback(callback)
        } finally {
            networkInfos.clear()
            updateNetworks()
        }
    }
}

private const val DNS_PORT = 53

private fun InetAddress.asSocketAddressText(port: Int): String = when (this) {
    is Inet6Address -> "[$hostAddress]:$port"
    is Inet4Address -> "$hostAddress:$port"
    else -> error("Unsupported address type: ${javaClass.name}")
}
