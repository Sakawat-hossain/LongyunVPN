import 'dart:async';

import 'package:longyunvpn/core/interface.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:test/test.dart';

/// getProxies() is where "the core did not answer" and "the core has no
/// proxies" used to become the same value.
///
/// A null from invoke() — a dropped transport, a call that timed out — was
/// turned into `ProxiesData(proxies: {}, all: [])`, which is indistinguishable
/// from a core that genuinely holds nothing. updateGroups() then wrote that
/// empty list over a perfectly good server list, and the Servers page flipped
/// to "No Nodes Available". Since the refresh runs every few seconds off the
/// delay-test results, one dropped call was enough, and it never came back.
///
/// The distinction only exists if this method makes it, so it is tested here.
void main() {
  group('CoreHandlerInterface.getProxies', () {
    test('parses a real reply', () async {
      final core = _StubCore(
        completer: Completer<void>()..complete(),
        reply: const {
          'proxies': {
            'HK 香港L01': {'name': 'HK 香港L01', 'type': 'ss'},
          },
          'all': ['HK 香港L01'],
        },
      );

      final data = await core.getProxies();

      expect(data.all, ['HK 香港L01']);
      expect(data.proxies.keys, contains('HK 香港L01'));
    });

    test('an unanswered call throws rather than reporting zero proxies',
        () async {
      final core = _StubCore(
        completer: Completer<void>()..complete(),
        reply: null,
      );

      await expectLater(
        core.getProxies(),
        throwsA(isA<CoreUnavailableException>()),
      );
    });

    test('says the core did not reply when the transport is up', () async {
      final core = _StubCore(
        completer: Completer<void>()..complete(),
        reply: null,
      );

      await expectLater(
        core.getProxies(),
        throwsA(
          isA<CoreUnavailableException>().having(
            (e) => e.reason,
            'reason',
            'no reply from core',
          ),
        ),
      );
    });

    test('says the transport is disconnected when it never connected', () async {
      // A completer that is never completed is exactly what the transport
      // installs on disconnect, and it is the state the app sits in between a
      // core dying and the reconnect landing.
      final core = _StubCore(completer: Completer<void>(), reply: null);

      await expectLater(
        core.getProxies(),
        throwsA(
          isA<CoreUnavailableException>().having(
            (e) => e.reason,
            'reason',
            'transport disconnected',
          ),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('an empty-but-real reply is still empty, not a failure', () async {
      // The other half of the contract: a core that answers with nothing has
      // genuinely got nothing, and the caller is right to clear the list.
      final core = _StubCore(
        completer: Completer<void>()..complete(),
        reply: const {'proxies': <String, dynamic>{}, 'all': <String>[]},
      );

      final data = await core.getProxies();

      expect(data.all, isEmpty);
      expect(data.proxies, isEmpty);
    });
  });
}

/// The real [CoreHandlerInterface] with only the two seams a caller cannot
/// control filled in: the transport's connection completer, and the reply that
/// comes back from a call. Everything else is forwarded to noSuchMethod, since
/// getProxies() is the only member under test.
class _StubCore extends CoreHandlerInterface {
  @override
  final Completer<void> completer;

  final Map<String, dynamic>? reply;

  _StubCore({required this.completer, required this.reply});

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    return reply as T?;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
