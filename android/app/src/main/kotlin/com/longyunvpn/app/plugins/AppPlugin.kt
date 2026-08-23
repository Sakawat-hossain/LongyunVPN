package com.longyunvpn.app.plugins

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ComponentInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.getSystemService
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.core.net.toUri
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile
import com.longyunvpn.app.R
import com.longyunvpn.app.common.Components
import com.longyunvpn.app.common.GlobalState
import com.longyunvpn.app.common.QuickAction
import com.longyunvpn.app.common.quickIntent
import com.longyunvpn.app.getPackageIconPath
import com.longyunvpn.app.models.Package
import com.longyunvpn.app.showToast
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.lang.ref.WeakReference
import java.util.zip.ZipFile

class AppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        const val VPN_PERMISSION_REQUEST_CODE = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002
    }

    private var activityRef: WeakReference<Activity>? = null

    private lateinit var channel: MethodChannel

    private lateinit var scope: CoroutineScope

    private var vpnPrepareCallback: (suspend () -> Unit)? = null

    private var requestNotificationCallback: (() -> Unit)? = null

    private val packages = mutableListOf<Package>()

    private val skipPrefixList = listOf(
        "com.google",
        "com.android.chrome",
        "com.android.vending",
        "com.microsoft",
        "com.apple",
        "com.zhiliaoapp.musically", // Banned by China
    )

    private val chinaAppPrefixList = listOf(
        "com.tencent",
        "com.alibaba",
        "com.umeng",
        "com.qihoo",
        "com.ali",
        "com.alipay",
        "com.amap",
        "com.sina",
        "com.weibo",
        "com.vivo",
        "com.xiaomi",
        "com.huawei",
        "com.taobao",
        "com.secneo",
        "s.h.e.l.l",
        "com.stub",
        "com.kiwisec",
        "com.secshell",
        "com.wrapper",
        "cn.securitystack",
        "com.mogosec",
        "com.secoen",
        "com.netease",
        "com.mx",
        "com.qq.e",
        "com.baidu",
        "com.bytedance",
        "com.bugly",
        "com.miui",
        "com.oppo",
        "com.coloros",
        "com.iqoo",
        "com.meizu",
        "com.gionee",
        "cn.nubia",
        "com.oplus",
        "andes.oplus",
        "com.unionpay",
        "cn.wps"
    )

    private val chinaAppRegex by lazy {
        ("(" + chinaAppPrefixList.joinToString("|").replace(".", "\\.") + ").*").toRegex()
    }

    private var isBlockNotification: Boolean = false

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "moveTaskToBack" -> {
                activityRef?.get()?.moveTaskToBack(true)
                result.success(true)
            }

            "updateExcludeFromRecents" -> {
                val value = call.argument<Boolean>("value")
                updateExcludeFromRecents(value)
                result.success(true)
            }

            "initShortcuts" -> {
                initShortcuts(call.arguments as String)
                result.success(true)
            }

            "getPackages" -> {
                scope.launch {
                    result.success(getPackagesToJson())
                }
            }

            "getChinaPackageNames" -> {
                scope.launch {
                    result.success(getChinaPackageNames())
                }
            }

            "getPackageIcon" -> {
                handleGetPackageIcon(call, result)
            }

            "tip" -> {
                val message = call.argument<String>("message")
                tip(message)
                result.success(true)
            }

            "isBatteryOptimizationDisabled" -> {
                result.success(isBatteryOptimizationDisabled())
            }

            "openBatteryOptimizationSettings" -> {
                result.success(openBatteryOptimizationSettings())
            }

            "openAppSettings" -> {
                result.success(openAppSettings())
            }

            "openVpnSettings" -> {
                result.success(openVpnSettings())
            }

            "getAbi" -> {
                result.success(getAbi())
            }

            "installApk" -> {
                result.success(installApk(call.argument<String>("path")))
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleGetPackageIcon(call: MethodCall, result: Result) {
        scope.launch {
            val packageName = call.argument<String>("packageName")
            if (packageName == null) {
                result.success("")
                return@launch
            }
            val path = GlobalState.application.packageManager.getPackageIconPath(packageName)
            result.success(path)
        }
    }

    private fun initShortcuts(label: String) {
        val shortcut = with(ShortcutInfoCompat.Builder(GlobalState.application, "toggle")) {
            setShortLabel(label)
            setIcon(
                IconCompat.createWithResource(
                    GlobalState.application,
                    R.mipmap.ic_launcher_round,
                )
            )
            setIntent(QuickAction.TOGGLE.quickIntent)
            build()
        }
        ShortcutManagerCompat.setDynamicShortcuts(
            GlobalState.application, listOf(shortcut)
        )
    }

    private fun tip(message: String?) {
        GlobalState.application.showToast(message)
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(GlobalState.application, PowerManager::class.java)
        return powerManager?.isIgnoringBatteryOptimizations(GlobalState.application.packageName)
            ?: false
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = "package:${GlobalState.application.packageName}".toUri()
            }
            activityRef?.get()?.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = "package:${GlobalState.application.packageName}".toUri()
            }
            activityRef?.get()?.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    // The ABI this device actually runs, so the updater downloads the matching
    // APK rather than guessing. SUPPORTED_ABIS is ordered best-first, so entry
    // zero is the one to use — an arm64 device lists arm64-v8a before the 32-bit
    // ABIs it can also run, and installing the 32-bit build on it would work but
    // be a silent downgrade.
    private fun getAbi(): String = Build.SUPPORTED_ABIS.firstOrNull() ?: ""

    /// Hands a downloaded APK to the system installer.
    ///
    /// Returns false when the APK can't be offered — a missing file, or the
    /// user hasn't granted "install unknown apps" for LongyunVPN. In the latter
    /// case the user is sent to the settings screen that grants it, because the
    /// install intent would otherwise be refused with nothing shown.
    ///
    /// This never installs anything by itself: Android shows its own confirm
    /// screen and the user approves there.
    private fun installApk(path: String?): Boolean {
        if (path.isNullOrEmpty()) return false
        val file = File(path)
        if (!file.exists()) {
            GlobalState.log("installApk: file missing at $path")
            return false
        }
        val context = activityRef?.get() ?: GlobalState.application
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !GlobalState.application.packageManager.canRequestPackageInstalls()
        ) {
            // Send them to the toggle rather than failing silently.
            return try {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    "package:${GlobalState.application.packageName}".toUri()
                ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                context.startActivity(intent)
                false
            } catch (e: Exception) {
                GlobalState.log("installApk: cannot open unknown-sources settings: $e")
                false
            }
        }
        return try {
            val uri = FileProvider.getUriForFile(
                GlobalState.application,
                "${GlobalState.application.packageName}.updateprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK
                )
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            GlobalState.log("installApk failed: $e")
            false
        }
    }

    // Opens the system VPN settings, where the user can enable Always-on VPN and
    // "Block connections without VPN" (Android's built-in kill switch — apps
    // cannot toggle it programmatically).
    private fun openVpnSettings(): Boolean {
        return try {
            activityRef?.get()?.startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    @Suppress("DEPRECATION")
    private fun updateExcludeFromRecents(value: Boolean?) {
        val am = getSystemService(GlobalState.application, ActivityManager::class.java)
        val task = am?.appTasks?.firstOrNull {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                it.taskInfo?.taskId == activityRef?.get()?.taskId
            } else {
                it.taskInfo?.id == activityRef?.get()?.taskId
            }
        }

        when (value) {
            true -> task?.setExcludeFromRecents(value)
            false -> task?.setExcludeFromRecents(value)
            null -> task?.setExcludeFromRecents(false)
        }
    }


    // getPackages and getChinaPackageNames each run in their own coroutine and
    // both populate this cache, so without the lock two concurrent calls can
    // both find it empty, both enumerate, and both append — leaving every app
    // in the list twice.
    @Synchronized
    private fun getPackages(): List<Package> {
        val packageManager = GlobalState.application.packageManager
        if (packages.isNotEmpty()) return packages
        packageManager?.getInstalledPackages(PackageManager.GET_META_DATA or PackageManager.GET_PERMISSIONS)
            ?.filter {
                it.packageName != GlobalState.application.packageName && it.packageName != "android"
            }?.map {
                Package(
                    packageName = it.packageName,
                    label = it.applicationInfo?.loadLabel(packageManager).toString(),
                    // Compare against 0 explicitly. `Int? != 0` is true when the
                    // flags are null, which labelled an app whose
                    // applicationInfo is missing as a system app and hid it from
                    // the picker.
                    system = ((it.applicationInfo?.flags ?: 0)
                        and ApplicationInfo.FLAG_SYSTEM) != 0,
                    lastUpdateTime = it.lastUpdateTime,
                    internet = it.requestedPermissions?.contains(Manifest.permission.INTERNET) == true
                )
            }?.let { packages.addAll(it) }
        return packages
    }

    private suspend fun getPackagesToJson(): String {
        return withContext(Dispatchers.Default) {
            Gson().toJson(getPackages())
        }
    }

    private suspend fun getChinaPackageNames(): String {
        return withContext(Dispatchers.Default) {
            val packages: List<String> =
                getPackages().map { it.packageName }.filter { isChinaPackage(it) }
            Gson().toJson(packages)
        }
    }

    fun requestNotificationsPermission(callBack: () -> Unit) {
        requestNotificationCallback = callBack
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = ContextCompat.checkSelfPermission(
                GlobalState.application, Manifest.permission.POST_NOTIFICATIONS
            )
            if (permission == PackageManager.PERMISSION_GRANTED || isBlockNotification) {
                invokeRequestNotificationCallback()
                return
            }
            activityRef?.get()?.let {
                ActivityCompat.requestPermissions(
                    it,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
            return
        } else {
            invokeRequestNotificationCallback()
        }

    }

    fun invokeRequestNotificationCallback() {
        requestNotificationCallback?.invoke()
        requestNotificationCallback = null
    }

    fun prepare(needPrepare: Boolean, callBack: (suspend () -> Unit)) {
        vpnPrepareCallback = callBack
        if (!needPrepare) {
            invokeVpnPrepareCallback()
            return
        }
        val intent = VpnService.prepare(GlobalState.application)
        if (intent != null) {
            activityRef?.get()?.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
            return
        }
        invokeVpnPrepareCallback()
    }

    fun invokeVpnPrepareCallback() {
        GlobalState.launch {
            vpnPrepareCallback?.invoke()
            vpnPrepareCallback = null
        }
    }


    @Suppress("DEPRECATION")
    private fun isChinaPackage(packageName: String): Boolean {
        val packageManager = GlobalState.application.packageManager ?: return false
        skipPrefixList.forEach {
            if (packageName == it || packageName.startsWith("$it.")) return false
        }
        val packageManagerFlags =
            PackageManager.MATCH_UNINSTALLED_PACKAGES or PackageManager.GET_ACTIVITIES or PackageManager.GET_SERVICES or PackageManager.GET_RECEIVERS or PackageManager.GET_PROVIDERS
        if (packageName.matches(chinaAppRegex)) {
            return true
        }
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName, PackageManager.PackageInfoFlags.of(packageManagerFlags.toLong())
                )
            } else {
                packageManager.getPackageInfo(
                    packageName, packageManagerFlags
                )
            }
            mutableListOf<ComponentInfo>().apply {
                packageInfo.services?.let { addAll(it) }
                packageInfo.activities?.let { addAll(it) }
                packageInfo.receivers?.let { addAll(it) }
                packageInfo.providers?.let { addAll(it) }
            }.forEach {
                if (it.name.matches(chinaAppRegex)) return true
            }
            packageInfo.applicationInfo?.publicSourceDir?.let {
                ZipFile(File(it)).use {
                    for (packageEntry in it.entries()) {
                        if (packageEntry.name.startsWith("firebase-")) return false
                    }
                    for (packageEntry in it.entries()) {
                        if (!(packageEntry.name.startsWith("classes") && packageEntry.name.endsWith(
                                ".dex"
                            ))
                        ) {
                            continue
                        }
                        if (packageEntry.size > 15000000) {
                            return true
                        }
                        val input = it.getInputStream(packageEntry).buffered()
                        val dexFile = try {
                            DexBackedDexFile.fromInputStream(null, input)
                        } catch (e: Exception) {
                            return false
                        }
                        for (clazz in dexFile.classes) {
                            val clazzName =
                                clazz.type.substring(1, clazz.type.length - 1).replace("/", ".")
                                    .replace("$", ".")
                            if (clazzName.matches(chinaAppRegex)) return true
                        }
                    }
                }
            }
        } catch (_: Exception) {
            return false
        }
        return false
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(Dispatchers.Default)
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "${Components.PACKAGE_NAME}/app")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
        binding.addActivityResultListener(::onActivityResult)
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityRef = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Re-register, don't just re-capture the activity. A configuration
        // change (rotation, theme switch, locale change) hands over a brand new
        // binding, and the listeners added to the old one are gone with it — so
        // without this the VPN-permission result never came back after a
        // rotation and connecting silently did nothing.
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        channel.invokeMethod("exit", null)
        activityRef = null
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == FlutterActivity.RESULT_OK) {
                invokeVpnPrepareCallback()
            } else {
                // Declining the VPN consent dialog used to fall through here
                // and do nothing at all: the pending callback was neither
                // invoked nor cleared, so the connect attempt waited forever
                // with nothing on screen to say it had been refused. Drop it so
                // the request ends, and so it can't fire against a later
                // attempt.
                GlobalState.log("VPN permission denied by user")
                vpnPrepareCallback = null
            }
        }
        return true
    }

    private fun onRequestPermissionsResultListener(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ): Boolean {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            isBlockNotification = true
        }
        invokeRequestNotificationCallback()
        return true
    }
}
