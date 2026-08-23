import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_ssid/wifi_ssid_manager.dart';

class Permissions {
  static Permissions? _instance;

  Permissions._internal();

  factory Permissions() {
    _instance ??= Permissions._internal();
    return _instance!;
  }

  bool _isRequestingLocation = false;
  bool needWaitingBatteryOptimizationSettings = false;

  void check() {
    checkLocationPermissions();
    checkBatteryOptimizationDisable();
  }

  Future<void> checkBatteryOptimizationDisable() async {
    await _checkBatteryOptimizationDisable();
  }

  Future<void> _checkBatteryOptimizationDisable() async {
    const tag = LoadingTag.batteryOptimization;
    try {
      if (needWaitingBatteryOptimizationSettings) {
        globalState.rootRef.read(loadingProvider(tag).notifier).value = true;
      }
      globalState.rootRef
          .read(batteryOptimizationDisableProvider.notifier)
          .value = await retry<bool>(
        task: () async {
          return await app?.isBatteryOptimizationDisabled() ?? false;
        },
        retryIf: (res) => res == false,
        delay: const Duration(milliseconds: 500),
        maxAttempts: needWaitingBatteryOptimizationSettings ? 5 : 1,
      );
    } finally {
      globalState.rootRef.read(loadingProvider(tag).notifier).value = false;
      needWaitingBatteryOptimizationSettings = false;
    }
  }

  Future<void> checkLocationPermissions() async {
    if (!(system.isAndroid || system.isMacOS)) {
      return;
    }
    final res = await WifiSsidManager.instance.checkPermission();
    final current = globalState.rootRef.read(locationPermissionsProvider);
    if (res == WifiSsidPermission.granted ||
        current != WifiSsidPermission.permanentlyDenied) {
      globalState.rootRef.read(locationPermissionsProvider.notifier).value =
          res;
    }
    final needRequestPermission = globalState.rootRef.read(
      excludeSSIDsProvider.select((state) => state.isNotEmpty),
    );
    if (res == WifiSsidPermission.denied &&
        needRequestPermission &&
        !_isRequestingLocation) {
      try {
        _isRequestingLocation = true;
        final res = await WifiSsidManager.instance.requestPermission();
        globalState.rootRef.read(locationPermissionsProvider.notifier).value =
            res;
        if (res != WifiSsidPermission.granted) {
          final ssid = await WifiSsidManager.instance.getSsid();
          globalState.rootRef.read(currentSSIDProvider.notifier).value = ssid;
        }
      } finally {
        _isRequestingLocation = false;
      }
    }
  }
}

final permissions = Permissions();
