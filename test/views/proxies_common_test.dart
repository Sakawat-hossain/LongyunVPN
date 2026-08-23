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
}
