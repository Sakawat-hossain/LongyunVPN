import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/system.dart';

/// Opened from Downloads or the disk image without being moved first, a macOS
/// app runs from a randomised read-only copy. There, authorising TUN fails and
/// launch at startup registers a path that is gone after a restart - so the
/// app has to recognise it and ask to be moved.
void main() {
  test('recognises a translocated copy', () {
    expect(
      isTranslocatedPath(
        '/private/var/folders/xy/abc123/T/AppTranslocation/'
        '5D1E4C2A-0B7E-4F55-9A1C-2B3D4E5F6A7B/d/LongyunVPN.app/'
        'Contents/MacOS/LongyunVPN',
      ),
      isTrue,
    );
  });

  test('leaves the places the app is meant to live alone', () {
    for (final path in [
      '/Applications/LongyunVPN.app/Contents/MacOS/LongyunVPN',
      '/Users/me/Applications/LongyunVPN.app/Contents/MacOS/LongyunVPN',
      '/Volumes/External/Applications/LongyunVPN.app/Contents/MacOS/LongyunVPN',
    ]) {
      expect(isTranslocatedPath(path), isFalse, reason: path);
    }
  });
}
