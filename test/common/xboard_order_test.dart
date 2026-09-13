import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/xboard.dart';

/// Order rows come from `GET /user/order/fetch`, which serialises the panel's
/// Order model through OrderResource. Xboard is loose with types on the way
/// out — an amount can be an int or a string, a timestamp can be absent, a plan
/// can be missing entirely — and a hard cast on any of them takes the whole
/// history down rather than one row of it.
///
/// The shapes here are built from a real row on admin.jsssbd.com.
void main() {
  group('XboardOrder.fromJson', () {
    test('parses a completed order the way the panel sends it', () {
      final order = XboardOrder.fromJson(const {
        'trade_no': '2026091319090376959961257',
        'plan_id': 6,
        'period': 'month_price',
        'total_amount': 500,
        'status': 3,
        'created_at': 1789298403,
        'paid_at': 1789298450,
        'plan': {'id': 6, 'name': 'PRO'},
      });

      expect(order.tradeNo, '2026091319090376959961257');
      expect(order.period, 'month_price');
      expect(order.totalAmount, 500);
      expect(order.status, 3);
      expect(order.planName, 'PRO');
      expect(order.paidAt, 1789298450);
      expect(order.isPayable, isFalse);
    });

    test('reads the legacy period key the purchase flow already knows', () {
      // OrderResource runs period back through getLegacyPeriod before sending
      // it, so it matches the key the app sends up at /user/order/save — which
      // is what lets the same label map serve both.
      final order = XboardOrder.fromJson(const {'period': 'month_price'});
      expect(xboardPeriods.containsKey(order.period), isTrue);
    });

    test('an unpaid order is the one the user can still act on', () {
      expect(XboardOrder.fromJson(const {'status': 0}).isPayable, isTrue);
      for (final status in [1, 2, 3, 4]) {
        expect(
          XboardOrder.fromJson({'status': status}).isPayable,
          isFalse,
          reason: 'status $status is not payable',
        );
      }
    });

    test('numbers survive arriving as strings', () {
      final order = XboardOrder.fromJson(const {
        'total_amount': '500',
        'status': '3',
        'created_at': '1789298403',
      });

      expect(order.totalAmount, 500);
      expect(order.status, 3);
      expect(order.createdAt, 1789298403);
    });

    test('a fully discounted order has no amount to report', () {
      // An upgrade whose surplus covers the price sends total_amount null.
      final order = XboardOrder.fromJson(const {
        'trade_no': 'x',
        'total_amount': null,
        'status': 4,
      });

      expect(order.totalAmount, 0);
      expect(order.status, 4);
    });

    test('a deleted plan leaves the row readable', () {
      // plan is eager-loaded and simply absent when the plan is gone. The row
      // still has to render — it is the user's own purchase history.
      final order = XboardOrder.fromJson(const {
        'trade_no': 'abc123',
        'status': 3,
      });

      expect(order.planName, isNull);
      expect(order.tradeNo, 'abc123');
    });

    test('a row with nothing in it does not throw', () {
      final order = XboardOrder.fromJson(const {});

      expect(order.tradeNo, '');
      expect(order.totalAmount, 0);
      expect(order.status, 0);
      expect(order.createdAt, isNull);
    });
  });
}
