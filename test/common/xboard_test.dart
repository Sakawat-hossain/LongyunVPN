import 'package:longyunvpn/common/xboard.dart';
import 'package:test/test.dart';

void main() {
  group('XboardPlan.fromJson', () {
    test('keeps only non-null period prices and decodes content features', () {
      final plan = XboardPlan.fromJson({
        'id': 5,
        'name': 'Pro',
        'month_price': 1000,
        'year_price': 10000,
        'onetime_price': null,
        'transfer_enable': 100,
        'sell': true,
        'reset_price': 500,
        'tags': ['hot'],
        'content':
            '[{"feature":"Unlimited","support":true},{"feature":"Ads","support":false}]',
      });

      expect(plan.id, 5);
      expect(plan.name, 'Pro');
      expect(plan.periodPrices['month_price'], 1000);
      expect(plan.periodPrices['year_price'], 10000);
      expect(plan.periodPrices.containsKey('onetime_price'), isFalse);
      expect(plan.resetPrice, 500);
      expect(plan.tags, ['hot']);
      expect(plan.features.length, 2);
      expect(plan.features.first.feature, 'Unlimited');
      expect(plan.features.first.support, isTrue);
      expect(plan.features[1].support, isFalse);
    });

    test('tolerates malformed content JSON without throwing', () {
      final plan = XboardPlan.fromJson({
        'id': 1,
        'name': 'Basic',
        'content': 'not-json',
      });
      expect(plan.features, isEmpty);
      expect(plan.periodPrices, isEmpty);
      expect(plan.sell, isTrue); // defaults to sellable when absent
    });
  });

  group('XboardUserInfo.fromJson', () {
    test('parses fields and applies numeric defaults', () {
      final u = XboardUserInfo.fromJson({
        'email': 'a@b.com',
        'plan_id': 2,
        'expired_at': 123,
      });
      expect(u.email, 'a@b.com');
      expect(u.planId, 2);
      expect(u.expiredAt, 123);
      expect(u.balance, 0);
      expect(u.transferEnable, 0);
    });
  });

  group('XboardCommConfig.fromJson', () {
    test('coerces the panel\'s numeric flags to booleans', () {
      final c = XboardCommConfig.fromJson({
        'is_email_verify': 1,
        'is_invite_force': 0,
        'is_captcha': 1,
        'email_whitelist_suffix': ['gmail.com'],
      });
      expect(c.isEmailVerify, isTrue);
      expect(c.isInviteForce, isFalse);
      expect(c.isCaptcha, isTrue);
      expect(c.emailWhitelistSuffix, ['gmail.com']);
    });

    test('defaults every flag to false when the payload is empty', () {
      final c = XboardCommConfig.fromJson({});
      expect(c.isEmailVerify, isFalse);
      expect(c.isInviteForce, isFalse);
      expect(c.isCaptcha, isFalse);
      expect(c.emailWhitelistSuffix, isEmpty);
    });
  });

  group('XboardSubscribeInfo.fromJson', () {
    test('parses usage and the nested plan object', () {
      final s = XboardSubscribeInfo.fromJson({
        'subscribe_url': 'https://sub/abc',
        'u': 10,
        'd': 20,
        'transfer_enable': 100,
        'expired_at': 999,
        'plan': {'name': 'Pro', 'device_limit': 3},
      });
      expect(s.subscribeUrl, 'https://sub/abc');
      expect(s.u, 10);
      expect(s.d, 20);
      expect(s.transferEnable, 100);
      expect(s.expiredAt, 999);
      expect(s.plan?['name'], 'Pro');
    });

    test('tolerates a missing subscribe_url', () {
      expect(XboardSubscribeInfo.fromJson({}).subscribeUrl, '');
    });
  });

  group('XboardPaymentMethod.fromJson', () {
    test('parses id/name/icon', () {
      final m = XboardPaymentMethod.fromJson({
        'id': 7,
        'name': 'Alipay',
        'icon': 'alipay.png',
      });
      expect(m.id, 7);
      expect(m.name, 'Alipay');
      expect(m.icon, 'alipay.png');
    });
  });

  group('XboardPlanFeature.fromJson', () {
    test('defaults support to true when absent', () {
      expect(XboardPlanFeature.fromJson({'feature': 'x'}).support, isTrue);
    });
  });
}
