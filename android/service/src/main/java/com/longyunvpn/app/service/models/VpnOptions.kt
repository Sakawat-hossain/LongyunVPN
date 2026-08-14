package com.longyunvpn.app.service.models

import android.os.Parcelable
import com.longyunvpn.app.common.AccessControlMode
import kotlinx.parcelize.Parcelize
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

@Parcelize
data class AccessControlProps(
    val enable: Boolean,
    val mode: AccessControlMode,
    val acceptList: List<String>,
    val rejectList: List<String>,
) : Parcelable

@Parcelize
data class VpnOptions(
    val enable: Boolean,
    val port: Int,
    val ipv6: Boolean,
    val dnsHijacking: Boolean,
    val accessControlProps: AccessControlProps,
    val allowBypass: Boolean,
    val systemProxy: Boolean,
    val bypassDomain: List<String>,
    val stack: String,
    val routeAddress: List<String>,
) : Parcelable

data class CIDR(val address: InetAddress, val prefixLength: Int)

// Each address is parsed exactly once and then sorted by the resulting type.
// Filtering with a separate isIpv4()/isIpv6() predicate first re-parsed every
// entry through InetAddress a second time, which is pure waste on the route
// tables that matter — a bypass-China list runs to thousands of CIDRs and this
// runs while the tunnel is coming up.
fun VpnOptions.getIpv4RouteAddress(): List<CIDR> = routeAddress
    .map(String::toCIDR)
    .filter { it.address is Inet4Address }

fun VpnOptions.getIpv6RouteAddress(): List<CIDR> = routeAddress
    .map(String::toCIDR)
    .filter { it.address is Inet6Address }

fun String.toCIDR(): CIDR {
    val parts = split("/")
    require(parts.size == 2) { "Invalid CIDR format: $this" }
    val ipAddress = parts[0]
    val prefixLength = parts[1].toIntOrNull()
        ?: throw IllegalArgumentException("Invalid prefix length: ${parts[1]}")

    val address = InetAddress.getByName(ipAddress)
    val maxPrefix = if (address.address.size == 4) 32 else 128
    require(prefixLength in 0..maxPrefix) {
        "Invalid prefix length $prefixLength for $ipAddress"
    }

    return CIDR(address, prefixLength)
}