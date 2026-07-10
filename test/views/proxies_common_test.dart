import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Proxy p(String name) => Proxy(name: name, type: 'ss');

  group('fastestProxyName (Quick Connect selection)', () {
    test('picks the lowest positive delay', () {
      const delays = {'A': 120, 'B': 40, 'C': 300};
      expect(
        fastestProxyName([p('A'), p('B'), p('C')], (n) => delays[n]),
        'B',
      );
    });

    test('ignores null / timeout / untested (non-positive) delays', () {
      const delays = {'A': null, 'B': 0, 'C': -1, 'D': 90};
      expect(
        fastestProxyName(
          [p('A'), p('B'), p('C'), p('D')],
          (n) => delays[n],
        ),
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
}
