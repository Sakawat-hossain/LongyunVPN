import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/xboard.dart';

/// Every panel call has to be bounded. Session restore runs behind a
/// full-screen spinner at launch, so an unbounded call that stalls - a panel
/// that accepts and never answers, a route that drops packets - holds the
/// whole app on that spinner with no error and no way past it.
void main() {
  test('panel calls time out instead of waiting forever', () {
    final options = XboardApi().options;
    for (final (name, timeout) in [
      ('connect', options.connectTimeout),
      ('receive', options.receiveTimeout),
      ('send', options.sendTimeout),
    ]) {
      expect(timeout, isNotNull, reason: '$name timeout is unbounded');
      expect(timeout!, greaterThan(Duration.zero), reason: name);
      expect(
        timeout,
        lessThanOrEqualTo(const Duration(minutes: 1)),
        reason: '$name timeout is too long to sit behind a spinner',
      );
    }
  });
}
