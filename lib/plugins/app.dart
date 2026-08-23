import 'dart:async';
import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class App {
  static App? _instance;
  late MethodChannel methodChannel;
  Function()? onExit;

  App._internal() {
    methodChannel = const MethodChannel('$packageName/app');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exit':
          if (onExit != null) {
            await onExit!();
          }
        default:
          throw MissingPluginException();
      }
    });
  }

  factory App() {
    _instance ??= App._internal();
    return _instance!;
  }

  Future<bool?> moveTaskToBack() async {
    return methodChannel.invokeMethod<bool>('moveTaskToBack');
  }

  Future<List<Package>> getPackages() async {
    final packagesString = await methodChannel.invokeMethod<String>(
      'getPackages',
    );
    final List<dynamic> packagesRaw =
        (await packagesString?.commonToJSON<List<dynamic>>()) ?? [];
    return packagesRaw.map((e) => Package.fromJson(e)).toSet().toList();
  }

  Future<List<String>> getChinaPackageNames() async {
    final packageNamesString = await methodChannel.invokeMethod<String>(
      'getChinaPackageNames',
    );
    final List<dynamic> packageNamesRaw =
        await packageNamesString?.commonToJSON<List<dynamic>>() ?? [];
    return packageNamesRaw.map((e) => e.toString()).toList();
  }

  Future<bool?> requestNotificationsPermission() async {
    return methodChannel.invokeMethod<bool>('requestNotificationsPermission');
  }

  Future<bool> openFile(String path) async {
    return await methodChannel.invokeMethod<bool>('openFile', {'path': path}) ??
        false;
  }

  /// Opens the system VPN settings (Always-on VPN / "Block connections without
  /// VPN" — the OS-level kill switch). Android only.
  Future<bool> openVpnSettings() async {
    return await methodChannel.invokeMethod<bool>('openVpnSettings') ?? false;
  }

  /// The device's primary ABI (e.g. `arm64-v8a`), so the updater can pick the
  /// matching APK instead of guessing. Empty when unavailable.
  Future<String> getAbi() async {
    return await methodChannel.invokeMethod<String>('getAbi') ?? '';
  }

  /// Hands a downloaded APK to Android's package installer.
  ///
  /// Returns false if it could not be offered — the file is missing, or
  /// "install unknown apps" is not granted, in which case the user is taken to
  /// the settings screen that grants it. Never installs silently: Android shows
  /// its own confirmation and the user approves there.
  Future<bool> installApk(String path) async {
    return await methodChannel.invokeMethod<bool>('installApk', {
          'path': path,
        }) ??
        false;
  }

  /// Icons resolved during this run, keyed by package name. A null value is a
  /// remembered miss, so a package with no readable icon is not asked for again
  /// on every rebuild.
  final Map<String, ImageProvider?> _packageIcons = {};

  /// Loads currently in flight, so rows that want the same icon at the same
  /// moment share one channel call instead of each making their own.
  final Map<String, Future<ImageProvider?>> _packageIconRequests = {};

  /// Whether [packageName]'s icon can be answered without an await. Lets a
  /// widget paint the icon on its very first frame instead of flashing an empty
  /// box while a Future it already knows the answer to completes.
  bool hasPackageIcon(String packageName) =>
      _packageIcons.containsKey(packageName);

  ImageProvider? cachedPackageIcon(String packageName) =>
      _packageIcons[packageName];

  /// The launcher icon for [packageName], or null if it has none.
  ///
  /// Resolving one crosses the method channel into a PackageManager lookup, and
  /// the connections list rebuilds about once a second while traffic flows — so
  /// without the cache every visible row re-fetched an icon that never changes.
  Future<ImageProvider?> getPackageIcon(String packageName) {
    if (packageName.isEmpty) {
      return Future.value(null);
    }
    if (_packageIcons.containsKey(packageName)) {
      return Future.value(_packageIcons[packageName]);
    }
    return _packageIconRequests[packageName] ??= _loadPackageIcon(packageName);
  }

  Future<ImageProvider?> _loadPackageIcon(String packageName) async {
    ImageProvider? icon;
    try {
      final path = await methodChannel.invokeMethod<String>('getPackageIcon', {
        'packageName': packageName,
      });
      icon = path == null || path.isEmpty ? null : FileImage(File(path));
    } catch (error) {
      // A missing icon is not worth failing a row over — remember the miss and
      // let the caller render its placeholder.
      commonPrint.log('getPackageIcon $packageName error: $error');
    }
    _packageIcons[packageName] = icon;
    _packageIconRequests.remove(packageName);
    return icon;
  }

  /// Forgets [packageName] so the next request re-reads it from the system.
  ///
  /// The Android side names the icon file after the package's lastUpdateTime
  /// and deletes the previous one, and it also ages files out on a TTL. Either
  /// way a cached [FileImage] can end up pointing at a file that no longer
  /// exists — which surfaces as an image load error, and that error is what
  /// drives this call (see `PackageIcon`). Flutter caches the failed resolution
  /// too, so the provider is evicted from the image cache as well; otherwise a
  /// retry would just be handed the same error back.
  void evictPackageIcon(String packageName) {
    final stale = _packageIcons.remove(packageName);
    _packageIconRequests.remove(packageName);
    if (stale != null) {
      unawaited(stale.evict());
    }
  }

  @visibleForTesting
  void clearPackageIconCache() {
    _packageIcons.clear();
    _packageIconRequests.clear();
  }

  Future<bool?> tip(String? message) async {
    return methodChannel.invokeMethod<bool>('tip', {'message': '$message'});
  }

  Future<bool?> initShortcuts() async {
    return methodChannel.invokeMethod<bool>(
      'initShortcuts',
      currentAppLocalizations.toggle,
    );
  }

  Future<bool?> updateExcludeFromRecents(bool value) async {
    return methodChannel.invokeMethod<bool>('updateExcludeFromRecents', {
      'value': value,
    });
  }

  Future<bool?> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    return methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
  }

  Future<bool?> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('openBatteryOptimizationSettings');
  }

  Future<bool?> openAppSettings() async {
    if (!Platform.isAndroid) return false;
    return methodChannel.invokeMethod<bool>('openAppSettings');
  }
}

final app = system.isAndroid ? App() : null;
