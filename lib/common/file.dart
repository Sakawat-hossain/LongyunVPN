import 'dart:io';

import 'package:fl_clash/enum/enum.dart';

import 'print.dart';

extension FileExt on File {
  Future<void> safeCopy(String newPath) async {
    if (!await exists()) {
      await create(recursive: true);
      return;
    }
    final targetFile = File(newPath);
    if (!await targetFile.exists()) {
      await targetFile.create(recursive: true);
    }
    await copy(newPath);
  }

  Future<File> safeWriteAsString(String str) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsString(str);
  }

  Future<File> safeWriteAsBytes(List<int> bytes) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsBytes(bytes);
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  /// Deletes the entity, ignoring the cases where deletion is not possible.
  ///
  /// The existence check alone is not enough: on Windows `delete` also throws
  /// when the file is locked by another process — a downloaded installer that
  /// is still running, or an antivirus scanning it — which used to escape as an
  /// unhandled PathAccessException and abort the caller (e.g. the updater).
  /// Deleting here is always best-effort cleanup, so failing is not fatal.
  Future<void> safeDelete({bool recursive = false}) async {
    try {
      if (!await exists()) {
        return;
      }
      await delete(recursive: recursive);
    } on FileSystemException catch (e) {
      commonPrint.log(
        'safeDelete failed for $path: ${e.osError?.message ?? e.message}',
        logLevel: LogLevel.warning,
      );
    }
  }
}
