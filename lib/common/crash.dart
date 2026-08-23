import 'dart:io';

import 'package:longyunvpn/common/path.dart';
import 'package:longyunvpn/common/print.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:flutter/foundation.dart';

/// Persistent, size-bounded crash capture.
///
/// [commonPrint] only keeps logs in memory, so a hard crash leaves no trace.
/// This appends uncaught framework/async errors and startup failures to
/// `crash.log` in the app data dir (with one rotated generation), so field
/// crashes can be inspected after the fact. Writing a crash record never itself
/// throws.
class CrashLog {
  CrashLog._();

  static const _maxBytes = 256 * 1024;
  static String? _cachedPath;
  static bool _installed = false;

  static Future<String?> _path() async {
    final cached = _cachedPath;
    if (cached != null) return cached;
    try {
      final dir = await appPath.homeDirPath;
      return _cachedPath = '$dir${Platform.pathSeparator}crash.log';
    } catch (_) {
      return null;
    }
  }

  /// The crash-log file path, for export/inspection. Null if it can't resolve.
  static Future<String?> filePath() => _path();

  /// Routes uncaught Flutter-framework errors and uncaught async
  /// (platform-dispatcher) errors into [record]. Call once, right after
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  static void install() {
    if (_installed) return;
    _installed = true;
    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      priorFlutterOnError?.call(details);
      record(details.exception, details.stack, context: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'async');
      return true;
    };
  }

  /// Appends one crash entry to the rolling log. Never throws.
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    final tag = context != null ? ' [$context]' : '';
    commonPrint.log('CRASH$tag: $error', logLevel: LogLevel.error);
    try {
      final path = await _path();
      if (path == null) return;
      final file = File(path);
      // Rotate to crash.log.old once the current file exceeds the cap so it
      // can't grow without bound; keep at most one previous generation.
      if (await file.exists() && await file.length() > _maxBytes) {
        final old = File('$path.old');
        try {
          if (await old.exists()) await old.delete();
          await file.rename(old.path);
        } catch (_) {
          try {
            await file.writeAsString('');
          } catch (_) {}
        }
      }
      final entry = StringBuffer()
        ..writeln('---- ${DateTime.now().toIso8601String()}$tag ----')
        ..writeln(error.toString());
      if (stack != null) entry.writeln(stack.toString());
      await file.writeAsString(
        entry.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Recording a crash must never itself crash.
    }
  }
}
