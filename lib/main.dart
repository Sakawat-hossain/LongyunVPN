import 'dart:async';
import 'dart:io';

import 'package:longyunvpn/pages/error.dart';
import 'package:longyunvpn/providers/config.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Capture uncaught framework/async errors to a persistent rolling log before
  // anything else runs, so field crashes leave a trace even on a hard exit.
  CrashLog.install();
  // Deliberately outside the try below: that catch puts the user on
  // InitErrorScreen, and Firebase failing to start — no network on a first
  // launch, a stale config — must never do that. FirebaseService.init swallows
  // its own failures and the app carries on with local crash logging only.
  // Nothing is collected until the settings switches say so.
  await FirebaseService.init();
  try {
    if (system.isDesktop) {
      await RustLib.init();
    }
    final version = await system.version;
    final container = await globalState.init(version);
    // Consent is stored per-user, so it can only be applied once the saved
    // config has been read. Until this runs both SDKs stay off, which is how
    // the platform manifests pin them.
    final appSetting = container.read(appSettingProvider);
    unawaited(
      FirebaseService.applyConsent(
        crashlytics: appSetting.crashlytics,
        analytics: appSetting.analytics,
      ),
    );
    HttpOverrides.global = LongyunHttpOverrides();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const Application(),
      ),
    );
  } catch (e, s) {
    await CrashLog.record(e, s, context: 'init');
    return runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
