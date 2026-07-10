import 'package:fl_clash/common/xboard.dart';
import 'package:fl_clash/providers/auth.dart';
import 'package:test/test.dart';

void main() {
  XboardUserInfo user({int? planId, int? expiredAt}) => XboardUserInfo(
        email: 'a@b.com',
        balance: 0,
        transferEnable: 0,
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
      expect(
        AuthState(userInfo: user(planId: 1, expiredAt: null))
            .hasActiveSubscription,
        isTrue,
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
