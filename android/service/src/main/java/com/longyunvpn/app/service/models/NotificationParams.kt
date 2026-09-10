package com.longyunvpn.app.service.models

data class NotificationParams(
    val title: String = "LongyunVPN",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
)
