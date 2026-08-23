import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/providers/app.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter/foundation.dart';

class CommonPrint {
  static CommonPrint? _instance;

  CommonPrint._internal();

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  void log(String? text, {LogLevel logLevel = LogLevel.info}) {
    final payload = '[APP] $text';
    // Only echo to the platform console in debug builds. debugPrint is NOT
    // stripped in release, so leaving it on would write app logs (which can
    // include URLs/PII) to logcat. The in-app log viewer below still records
    // them on the user's own device.
    if (kDebugMode) {
      debugPrint(payload);
    }
    if (!globalState.isAttach) {
      return;
    }
    globalState.rootRef
        .read(logsProvider.notifier)
        .add(Log.app(payload).copyWith(logLevel: logLevel));
  }
}

final commonPrint = CommonPrint();
