import 'dart:async';
import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase, on the two platforms that support it.
///
/// Android and macOS only — Firebase has no Flutter implementation for Windows
/// or Linux, and there is no iOS target. Everywhere else, and anywhere Firebase
/// fails to start, the app keeps using the on-device [CrashLog] alone.
///
/// Nothing is collected until the user says so. Both SDKs are pinned off in the
/// platform manifests, and collection is enabled only from [applyConsent],
/// driven by the two switches in Settings.
class FirebaseService {
  FirebaseService._();

  static bool _available = false;
  static bool _installed = false;

  /// Whether Firebase started successfully and can be talked to. False on
  /// Windows and Linux, and false on Android/macOS if initialization failed.
  static bool get isAvailable => _available;

  /// Brings Firebase up, if this platform has it.
  ///
  /// Never throws and never blocks startup on a failure: no network on first
  /// launch, a config that does not match the running bundle id, a project that
  /// has been deleted — none of those should stop a VPN client from starting.
  /// A failure here just means crash reporting stays local.
  static Future<void> init() async {
    if (!DefaultFirebaseOptions.isSupported) return;
    try {
      // Bounded, because a throw is not the only way this can go wrong. This
      // runs before runApp, so a platform channel that never answers — a wedged
      // native SDK, a Play Services process misbehaving — would hold the app on
      // a blank screen indefinitely with no error to catch. Ten seconds is far
      // longer than a healthy init needs; past that, start the VPN client and
      // leave crash reporting local.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
      _available = true;
      _installErrorHandlers();
    } catch (error, stack) {
      // Record it locally so a Firebase that never starts is at least
      // diagnosable from the on-device log.
      await CrashLog.record(error, stack, context: 'firebase-init');
      commonPrint.log(
        'Firebase unavailable, continuing with local crash logging: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// Adds Crashlytics to the error paths [CrashLog] already owns, rather than
  /// replacing them: the local log stays the source of truth on every platform,
  /// and Crashlytics is an extra sink that only forwards once consent is on.
  static void _installErrorHandlers() {
    if (_installed) return;
    _installed = true;
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      priorOnError?.call(details);
      // Non-fatal on purpose. Flutter catches framework errors and keeps
      // running — a layout overflow or a setState-after-dispose reaches here
      // without the app dying. Recording them as fatal (the pattern FlutterFire
      // documents) would sink the crash-free-users figure and bury the crashes
      // that actually matter. Genuine app-killing errors arrive through
      // PlatformDispatcher.onError below, and those are reported as fatal.
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return priorPlatformOnError?.call(error, stack) ?? true;
    };
  }

  /// Points the two SDKs at the user's current choices.
  ///
  /// Safe to call repeatedly — it runs on every settings change and once at
  /// startup. Turning a switch off stops collection from that moment; reports
  /// already sent cannot be recalled, which is why both start off.
  static Future<void> applyConsent({
    required bool crashlytics,
    required bool analytics,
  }) async {
    if (!_available) return;
    // Applied independently. Sharing one try meant a failure setting Crashlytics
    // skipped Analytics entirely — so a user switching Analytics off could be
    // left with it still on, which is the one direction that must never fail
    // quietly.
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        crashlytics,
      );
    } catch (error) {
      commonPrint.log(
        'Crashlytics consent update failed: $error',
        logLevel: LogLevel.warning,
      );
    }
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(analytics);
    } catch (error) {
      commonPrint.log(
        'Analytics consent update failed: $error',
        logLevel: LogLevel.warning,
      );
    }
  }

  /// Records a non-fatal error. A no-op unless Firebase started and the user
  /// turned crash reporting on — the SDK drops it when collection is disabled.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    if (!_available) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
      );
    } catch (_) {
      // Reporting must never become the thing that breaks.
    }
  }
}

/// True on platforms that have no Firebase at all, so callers can describe the
/// crash-reporting story honestly in the UI.
bool get isFirebasePlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isMacOS);
