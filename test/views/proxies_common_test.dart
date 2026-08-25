import 'dart:io';

import 'package:longyunvpn/common/constant.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Proxy p(String name) => Proxy(name: name, type: 'ss');

  group('fastestProxyName (Quick Connect selection)', () {
    test('picks the lowest positive delay', () {
      const delays = {'A': 120, 'B': 40, 'C': 300};
      expect(fastestProxyName([p('A'), p('B'), p('C')], (n) => delays[n]), 'B');
    });

    test('ignores null / timeout / untested (non-positive) delays', () {
      const delays = {'A': null, 'B': 0, 'C': -1, 'D': 90};
      expect(
        fastestProxyName([p('A'), p('B'), p('C'), p('D')], (n) => delays[n]),
        'D',
      );
    });

    test('returns null when no node has a usable delay', () {
      expect(
        fastestProxyName([p('A'), p('B')], (n) => n == 'A' ? 0 : null),
        isNull,
      );
    });

    test('never selects an excluded built-in proxy, even if fastest', () {
      const delays = {'DIRECT': 1, 'X': 50};
      expect(
        fastestProxyName(
          [p('DIRECT'), p('X')],
          (n) => delays[n],
          exclude: const {'DIRECT'},
        ),
        'X',
      );
    });
  });

  group('delay-test concurrency', () {
    // maxConcurrentDelayTests exists to stay within the core's own delay-test
    // concurrency. If either side is retuned without the other, the surplus
    // requests queue inside the core behind a full wave of timeouts and come
    // back as "timeout" for nodes that are actually reachable — so pin the
    // relationship rather than trusting the comment.
    test('stays at or below the core mBatch concurrency', () {
      final source = File('core/common.go').readAsStringSync();
      final match = RegExp(
        r'WithConcurrencyNum\[bool\]\((\d+)\)',
      ).firstMatch(source);

      expect(
        match,
        isNotNull,
        reason: 'mBatch concurrency not found in core/common.go',
      );
      expect(
        maxConcurrentDelayTests,
        lessThanOrEqualTo(int.parse(match!.group(1)!)),
      );
    });
  });

  group('panel info rows are not servers', () {
    // Real entries taken from a live Xboard subscription. These arrive in the
    // proxy group alongside real nodes, and were being rendered as ordinary
    // tappable cards — selecting one connects the user to nothing.
    test('rejects the info rows a subscription injects', () {
      for (final name in [
        '剩余流量：102.07 GB',
        '距离下次重置剩余：20 天',
        '套餐到期：2026-09-14',
      ]) {
        expect(isRealServerNode(name), isFalse, reason: name);
      }
    });

    test('keeps every real node from the same subscription', () {
      for (final name in [
        'HK 香港L01 | x1',
        'HK 香港L01 | IEPL |x1',
        'JP 日本L01 | IPEL | x1',
        'SG 新加坡L01 | IEPL | x1',
        'BD 孟加拉国L01 | x1',
      ]) {
        expect(isRealServerNode(name), isTrue, reason: name);
      }
    });

    test('realServerNodes filters a mixed list', () {
      final mixed = [
        const Proxy(name: '套餐到期：2026-09-14', type: 'ss'),
        const Proxy(name: 'HK 香港L01 | IEPL |x1', type: 'ss'),
        const Proxy(name: '剩余流量：102.07 GB', type: 'ss'),
        const Proxy(name: 'JP 日本L02 | x1', type: 'ss'),
      ];
      expect(realServerNodes(mixed).map((p) => p.name), [
        'HK 香港L01 | IEPL |x1',
        'JP 日本L02 | x1',
      ]);
    });

    test('quick-connect never selects an info row, even if it answers', () {
      final proxies = [
        const Proxy(name: '剩余流量：102.07 GB', type: 'ss'),
        const Proxy(name: 'HK 香港L01 | IEPL |x1', type: 'ss'),
      ];
      // The info row reports the better latency; it must still be skipped.
      const delays = {'剩余流量：102.07 GB': 1, 'HK 香港L01 | IEPL |x1': 200};
      expect(
        fastestProxyName(proxies, (n) => delays[n]),
        'HK 香港L01 | IEPL |x1',
      );
    });
  });
}
