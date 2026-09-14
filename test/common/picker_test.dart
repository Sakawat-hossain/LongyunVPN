import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/picker.dart';

/// saveFileWithPath used to destroy the file it was asked to export.
///
/// It began life serving one caller — a temp file written purely so it could be
/// exported — so deleting the source afterwards was correct and unconditional.
/// Later callers handed it files the app depends on: Export effective config
/// passes the live config the core reads, Export crash log passes the crash log
/// itself. Both were deleted on the way out, and deleted even when the save
/// dialog was cancelled, since the delete ran regardless of the result.
///
/// Removal is opt-in now. Only the early-exit is exercised here: everything past
/// it opens a native save dialog, which a unit test has no way to answer.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('picker_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('Picker.saveFileWithPath', () {
    test('a missing source exports nothing instead of an empty file', () async {
      final missing = File('${dir.path}/never-written.yaml');
      expect(missing.existsSync(), isFalse);

      final result = await picker.saveFileWithPath('out.yaml', missing.path);

      // The old code created the file here and carried on, which put an empty
      // document in front of the user and reported it as a successful export.
      expect(result, isNull);
      expect(
        missing.existsSync(),
        isFalse,
        reason: 'a missing source must not be conjured into existence',
      );
    });

    test('deleting the source is off unless asked for', () {
      // The guarantee this whole change rests on, stated where it can be read:
      // the default must stay false, or exporting the effective config silently
      // deletes the config the core is running from.
      const signature = 'bool deleteSource = false';
      final source = File('lib/common/picker.dart').readAsStringSync();
      expect(
        source.contains(signature),
        isTrue,
        reason: 'saveFileWithPath must not delete the caller\'s file by default',
      );
    });
  });
}
