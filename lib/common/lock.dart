import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';

class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  /// Takes the single-instance lock, retrying for a few seconds.
  ///
  /// An instance that is on its way out holds this lock until the process
  /// actually dies, and exit is deliberately delayed by a few seconds to let
  /// the core shut down. Relaunching inside that window — which is exactly what
  /// happens after "Clear Data" restarts the app, or when a user reopens it
  /// straight after quitting — used to fail on the first try and take the new
  /// instance down silently, so the app appeared to open and immediately close.
  /// Retrying covers the handover; a genuine second instance still gives up
  /// once the window has passed.
  Future<bool> acquire() async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    var attempt = 0;
    while (true) {
      try {
        final lockFilePath = await appPath.lockFilePath;
        final lockFile = File(lockFilePath);
        await lockFile.create();
        _accessFile = await lockFile.open(mode: FileMode.write);
        await _accessFile?.lock();
        return true;
      } catch (e) {
        await _accessFile?.close().catchError((_) {});
        _accessFile = null;
        if (DateTime.now().isAfter(deadline)) {
          commonPrint.log(
            'single-instance lock unavailable after ${attempt + 1} attempts: $e',
            logLevel: LogLevel.warning,
          );
          return false;
        }
        attempt++;
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }
}

final singleInstanceLock = SingleInstanceLock();
