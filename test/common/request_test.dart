import 'package:longyunvpn/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Dio leaves every timeout null by default, which means "wait forever".
  // Adding a subscription fetches it over these clients behind a modal
  // spinner, so an unbounded request showed up as a profile that never
  // finished loading, with no error and no way to dismiss it.
  group('Request HTTP clients are bounded', () {
    test('subscription/profile client has connect and receive timeouts', () {
      final options = request.clashDioOptions;
      expect(
        options.connectTimeout,
        isNotNull,
        reason: 'a stalled connect would hang the add-profile spinner forever',
      );
      expect(
        options.receiveTimeout,
        isNotNull,
        reason: 'a server that connects but never replies must not hang',
      );
      expect(options.sendTimeout, isNotNull);
    });

    test('general client has connect and receive timeouts', () {
      final options = request.dioOptions;
      expect(options.connectTimeout, isNotNull);
      expect(options.receiveTimeout, isNotNull);
      expect(options.sendTimeout, isNotNull);
    });

    test('timeouts are bounded to something a user will wait through', () {
      for (final options in [request.clashDioOptions, request.dioOptions]) {
        expect(
          options.connectTimeout,
          lessThanOrEqualTo(const Duration(seconds: 30)),
        );
        expect(
          options.receiveTimeout,
          lessThanOrEqualTo(const Duration(minutes: 2)),
        );
      }
    });
  });
}
