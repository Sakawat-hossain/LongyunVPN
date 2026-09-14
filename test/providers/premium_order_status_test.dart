import 'package:longyunvpn/providers/premium.dart';
import 'package:test/test.dart';

/// "I've paid" used to call refreshStatus alone, which answers for the account
/// and not for the order. Anyone who already held an active plan — a renewal,
/// an upgrade, anyone buying a second time — pressed it, was told the purchase
/// had gone through, had the pending banner cleared and was sent to the
/// dashboard, while the order sat unpaid on the panel with no route back to it.
///
/// The panel has always been able to answer this: getOrderStatus existed and was
/// never called. This is the mapping from its answer to what the user is told.
void main() {
  group('PremiumNotifier.resultForStatus', () {
    test('only a settled order counts as activated', () {
      // 3 completed, 4 discounted (absorbed into an upgrade).
      expect(
        PremiumNotifier.resultForStatus(3),
        PendingOrderResult.activated,
      );
      expect(
        PremiumNotifier.resultForStatus(4),
        PendingOrderResult.activated,
      );
    });

    test('an unpaid order is never reported as activated', () {
      expect(PremiumNotifier.resultForStatus(0), PendingOrderResult.unpaid);
    });

    test('a payment still settling says so rather than claiming success', () {
      expect(
        PremiumNotifier.resultForStatus(1),
        PendingOrderResult.processing,
      );
    });

    test('a cancelled order is reported as cancelled', () {
      expect(PremiumNotifier.resultForStatus(2), PendingOrderResult.cancelled);
    });

    test('an unreadable answer is treated as unpaid, not as paid', () {
      // getOrderStatus returns -1 when the panel's reply cannot be parsed.
      // Guessing "paid" there would hand out service for nothing; guessing
      // "unpaid" costs a user one more tap. Be wrong in that direction.
      expect(PremiumNotifier.resultForStatus(-1), PendingOrderResult.unpaid);
    });

    test('a status the panel has not invented yet is treated as unpaid', () {
      for (final status in [5, 9, 42, -7]) {
        expect(
          PremiumNotifier.resultForStatus(status),
          PendingOrderResult.unpaid,
          reason: 'status $status must not activate anything',
        );
      }
    });

    test('activated is reachable from exactly two statuses', () {
      final activating = [
        for (var status = -5; status <= 20; status++)
          if (PremiumNotifier.resultForStatus(status) ==
              PendingOrderResult.activated)
            status,
      ];
      expect(activating, [3, 4]);
    });
  });
}
