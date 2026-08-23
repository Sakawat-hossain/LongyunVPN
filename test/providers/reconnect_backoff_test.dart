import 'package:longyunvpn/providers/action.dart';
import 'package:test/test.dart';

void main() {
  group('CoreAction.reconnectDelayFor (auto-reconnect backoff policy)', () {
    test('follows the capped exponential schedule', () {
      expect(CoreAction.reconnectDelayFor(0), const Duration(seconds: 2));
      expect(CoreAction.reconnectDelayFor(1), const Duration(seconds: 4));
      expect(CoreAction.reconnectDelayFor(2), const Duration(seconds: 8));
      expect(CoreAction.reconnectDelayFor(3), const Duration(seconds: 16));
      expect(CoreAction.reconnectDelayFor(4), const Duration(seconds: 30));
    });

    test('gives up (null) once the attempt cap is reached', () {
      expect(CoreAction.reconnectDelayFor(5), isNull);
      expect(CoreAction.reconnectDelayFor(6), isNull);
      expect(CoreAction.reconnectDelayFor(100), isNull);
    });

    test('delays are monotonically non-decreasing', () {
      Duration? prev;
      for (var attempt = 0; ; attempt++) {
        final delay = CoreAction.reconnectDelayFor(attempt);
        if (delay == null) break;
        if (prev != null) {
          expect(delay >= prev, isTrue, reason: 'attempt $attempt regressed');
        }
        prev = delay;
      }
      expect(prev, const Duration(seconds: 30));
    });
  });
}
