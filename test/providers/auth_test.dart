import 'package:longyunvpn/common/xboard.dart';
import 'package:longyunvpn/providers/auth.dart';
import 'package:test/test.dart';

void main() {
  XboardUserInfo user({
    int? planId,
    int? expiredAt,
    num transferEnable = 0,
  }) =>
      XboardUserInfo(
        email: 'a@b.com',
        balance: 0,
        transferEnable: transferEnable,
        planId: planId,
        expiredAt: expiredAt,
      );

  int unixOffset(Duration d) =>
      DateTime.now().add(d).millisecondsSinceEpoch ~/ 1000;

  group('AuthState.hasActiveSubscription', () {
    test('false when there is no user info', () {
      expect(const AuthState().hasActiveSubscription, isFalse);
    });

    test('false when the account has no plan', () {
      expect(
        AuthState(userInfo: user(planId: null)).hasActiveSubscription,
        isFalse,
      );
    });

    test('true for a plan with no expiry (lifetime)', () {
      // A real lifetime plan carries a data allowance. This case previously
      // passed with a zero allowance too, which is what let an unpaid account
      // read as a lifetime subscriber.
      expect(
        AuthState(
          userInfo: user(planId: 1, expiredAt: null, transferEnable: 1024),
        ).hasActiveSubscription,
        isTrue,
      );
    });

    test('false for a plan id with no expiry and no allowance', () {
      // Starting checkout is enough for the panel to assign a plan id, and an
      // unpaid account has no expiry either — that combination must not grant
      // Premium.
      expect(
        AuthState(userInfo: user(planId: 1, expiredAt: null))
            .hasActiveSubscription,
        isFalse,
      );
    });

    test('true when the plan expires in the future', () {
      expect(
        AuthState(userInfo: user(planId: 1, expiredAt: unixOffset(const Duration(days: 1))))
            .hasActiveSubscription,
        isTrue,
      );
    });

    test('false when the plan has already expired', () {
      expect(
        AuthState(userInfo: user(planId: 1, expiredAt: unixOffset(const Duration(days: -1))))
            .hasActiveSubscription,
        isFalse,
      );
    });
  });
}
