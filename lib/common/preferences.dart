import 'dart:async';
import 'dart:convert';

import 'package:longyunvpn/models/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constant.dart';

class Preferences {
  static Preferences? _instance;
  Completer<SharedPreferences?> sharedPreferencesCompleter = Completer();

  // The Xboard session token is a full bearer credential, so it lives in the OS
  // keystore (Keychain / DPAPI-backed Credential Locker / Android Keystore /
  // libsecret) rather than plaintext SharedPreferences.
  static const _xboardTokenKey = 'xboardToken';
  // No AndroidOptions: the EncryptedSharedPreferences backend we used to ask
  // for is gone. Google deprecated Jetpack Security, so flutter_secure_storage
  // 10 replaced it with its own ciphers (AES-GCM, RSA-OAEP-SHA256), ignores the
  // old flag, and migrates existing entries to the new format the first time
  // they are read — so tokens written by earlier builds survive the upgrade and
  // nobody is silently logged out.
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<bool> get isInit async =>
      await sharedPreferencesCompleter.future != null;

  Preferences._internal() {
    SharedPreferences.getInstance()
        .then((value) => sharedPreferencesCompleter.complete(value))
        .onError((_, _) => sharedPreferencesCompleter.complete(null));
  }

  factory Preferences() {
    _instance ??= Preferences._internal();
    return _instance!;
  }

  Future<int> getVersion() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getInt('version') ?? 0;
  }

  Future<void> setVersion(int version) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setInt('version', version);
  }

  Future<void> saveShareState(SharedState shareState) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString('sharedState', json.encode(shareState));
  }

  Future<Map<String, Object?>?> getConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final configString = preferences?.getString(configKey);
      if (configString == null) return null;
      final Map<String, Object?>? configMap = json.decode(configString);
      return configMap;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>?> getClashConfigMap() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      final clashConfigString = preferences?.getString(clashConfigKey);
      if (clashConfigString == null) return null;
      return json.decode(clashConfigString);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearClashConfig() async {
    try {
      final preferences = await sharedPreferencesCompleter.future;
      await preferences?.remove(clashConfigKey);
      return;
    } catch (_) {
      return;
    }
  }

  Future<Config?> getConfig() async {
    final configMap = await getConfigMap();
    if (configMap == null) {
      return null;
    }
    return Config.fromJson(configMap);
  }

  Future<bool> saveConfig(Config config) async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.setString(configKey, json.encode(config)) ?? false;
  }

  Future<void> clearPreferences() async {
    final sharedPreferencesIns = await sharedPreferencesCompleter.future;
    await sharedPreferencesIns?.clear();
  }

  Future<String?> getXboardToken() async {
    try {
      // One-time migration: older builds kept the token in plaintext
      // SharedPreferences. If we find it there, move it into the keystore and
      // wipe the plaintext copy so returning users aren't logged out.
      final preferences = await sharedPreferencesCompleter.future;
      final legacy = preferences?.getString(_xboardTokenKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _secureStorage.write(key: _xboardTokenKey, value: legacy);
        await preferences?.remove(_xboardTokenKey);
        return legacy;
      }
      return await _secureStorage.read(key: _xboardTokenKey);
    } catch (_) {
      // Keystore unavailable (e.g. no secret service on a headless Linux
      // session) — fail closed: report no token so the user simply logs in
      // again rather than crashing.
      return null;
    }
  }

  Future<void> setXboardToken(String token) async {
    try {
      await _secureStorage.write(key: _xboardTokenKey, value: token);
    } catch (_) {}
  }

  Future<void> clearXboardToken() async {
    try {
      await _secureStorage.delete(key: _xboardTokenKey);
    } catch (_) {}
    // Also drop any leftover plaintext copy from a pre-migration install.
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.remove(_xboardTokenKey);
  }

  /// The release tag the user chose to skip in the update dialog. Automatic
  /// checks suppress this one version; manual checks still show it.
  Future<String?> getSkippedUpdateVersion() async {
    final preferences = await sharedPreferencesCompleter.future;
    return preferences?.getString('skippedUpdateVersion');
  }

  Future<void> setSkippedUpdateVersion(String version) async {
    final preferences = await sharedPreferencesCompleter.future;
    await preferences?.setString('skippedUpdateVersion', version);
  }
}

final preferences = Preferences();
