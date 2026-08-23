import 'package:longyunvpn/common/xboard.dart';
import 'package:longyunvpn/providers/auth.dart';
import 'package:flutter_test/flutter_test.dart';

int _ts(Duration offset) =>
    DateTime.now().add(offset).millisecondsSinceEpoch ~/ 1000;

AuthState _withUser({
  int? planId,
  int? expiredAt,
  num transferEnable = 0,
}) {
  return AuthState(
    userInfo: XboardUserInfo(
      email: 'a@b.c',
      balance: 0,
      transferEnable: transferEnable,
      expiredAt: expiredAt,
      planId: planId,
    ),
  );
}

void main() {
  group('hasActiveSubscription', () {
    test('no account is not active', () {
      expect(const AuthState().hasActiveSubscription, isFalse);
    });

    test('no plan is not active', () {
      expect(_withUser(planId: null).hasActiveSubscription, isFalse);
    });

    test('a plan expiring in the future is active', () {
      final state = _withUser(planId: 1, expiredAt: _ts(const Duration(days: 30)));
      expect(state.hasActiveSubscription, isTrue);
    });

    test('an expired plan is not active', () {
      final state = _withUser(planId: 1, expiredAt: _ts(const Duration(days: -1)));
      expect(state.hasActiveSubscription, isFalse);
    });

    test('a dated plan is trusted even with a zero allowance', () {
      // Some panels report unlimited traffic as zero. An explicit expiry date
      // is the panel's own statement about the subscription, so it wins —
      // tightening this would lock out paying users.
      final state = _withUser(
        planId: 1,
        expiredAt: _ts(const Duration(days: 30)),
        transferEnable: 0,
      );
      expect(state.hasActiveSubscription, isTrue);
    });

    test('a lifetime plan with an allowance is active', () {
      final state = _withUser(planId: 1, transferEnable: 1024);
      expect(state.hasActiveSubscription, isTrue);
    });

    test('a plan id with no expiry and no allowance is NOT active', () {
      // The regression that handed out Premium for free: starting checkout is
      // enough for the panel to assign a plan id, and an unpaid account has no
      // expiry either. Treating that as a lifetime plan granted access without
      // payment, and the subscription it imported had no nodes in it.
      final state = _withUser(planId: 1, transferEnable: 0);
      expect(
        state.hasActiveSubscription,
        isFalse,
        reason: 'an unpaid plan id must not read as a lifetime subscription',
      );
    });
  });

  group('XboardSubscribeInfo.effectiveDeviceLimit', () {
    test('prefers the account\'s live limit over the plan default', () {
      final info = XboardSubscribeInfo.fromJson({
        'subscribe_url': 'https://example.com/s',
        'device_limit': 5,
        'plan': {'device_limit': 3},
      });
      expect(info.effectiveDeviceLimit, 5);
    });

    test('falls back to the plan default when the panel sends no live value',
        () {
      final info = XboardSubscribeInfo.fromJson({
        'subscribe_url': 'https://example.com/s',
        'plan': {'device_limit': 3},
      });
      expect(info.effectiveDeviceLimit, 3);
    });

    test('is null when neither is present, rather than throwing', () {
      final info = XboardSubscribeInfo.fromJson({
        'subscribe_url': 'https://example.com/s',
      });
      expect(info.effectiveDeviceLimit, isNull);
    });

    test('reads the live reset fields', () {
      final info = XboardSubscribeInfo.fromJson({
        'subscribe_url': 'https://example.com/s',
        'reset_day': 12,
        'next_reset_at': 1770000000,
      });
      expect(info.resetDay, 12);
      expect(info.nextResetAt, 1770000000);
    });
  });
}
