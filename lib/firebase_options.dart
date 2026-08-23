// Firebase configuration, transcribed from the platform config files that ship
// with the project:
//
//   android/app/google-services.json
//   macos/Runner/GoogleService-Info.plist
//
// Those two files remain the source of truth for the native SDKs — this only
// mirrors them for the Dart side. Keep the values here in step with them.
//
// Only Android and macOS are configured. Firebase has no Flutter support on
// Windows or Linux, and there is no iOS target in this project, so those
// platforms throw rather than silently reporting to the wrong app; callers are
// expected to gate on [isSupported] before initializing.

import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// Whether Firebase can run on the platform this build is for. Everything
  /// that touches Firebase checks this first.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isMacOS);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('LongyunVPN has no web target.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.iOS:
        throw UnsupportedError('LongyunVPN has no iOS target.');
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is not available on $defaultTargetPlatform — these builds '
          'use the on-device CrashLog instead.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA32FD82riXY_QI5zG7k09rgaSt5DcjUTI',
    appId: '1:783301981225:android:c93f08c473d3522aae1838',
    messagingSenderId: '783301981225',
    projectId: 'jsss-group',
    storageBucket: 'jsss-group.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBb3oPoRyApoO8fUkwPOPzFC1IxsK4My50',
    appId: '1:783301981225:ios:e6b56ca99e126a97ae1838',
    messagingSenderId: '783301981225',
    projectId: 'jsss-group',
    storageBucket: 'jsss-group.firebasestorage.app',
    // Firebase registers macOS apps as Apple apps, so the bundle id is carried
    // under the iOS field and the app id above reads ":ios:". Both are correct.
    iosBundleId: 'com.longyunvpn.app',
  );
}
