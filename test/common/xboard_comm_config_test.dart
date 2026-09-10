import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/xboard.dart';

/// This config is what tells the signup form whether a verification code is
/// required. Losing it does not disable a nicety — it lets someone submit a
/// registration the panel will reject, with the form showing nothing useful.
///
/// It was lost to a type: the live panel returns `email_whitelist_suffix: 0`
/// when the whitelist is off, and the parser cast that to a List. So parsing
/// threw, the app never saw is_email_verify: 1, and signup could not succeed.
void main() {
  group('XboardCommConfig.fromJson', () {
    test('parses the payload the live panel actually returns', () {
      // Verbatim from admin.jsssbd.com/api/v1/guest/comm/config.
      final config = XboardCommConfig.fromJson(const {
        'is_email_verify': 1,
        'is_invite_force': 0,
        'email_whitelist_suffix': 0,
        'is_captcha': 0,
      });
      expect(config.isEmailVerify, isTrue);
      expect(config.isInviteForce, isFalse);
      expect(config.isCaptcha, isFalse);
      expect(config.emailWhitelistSuffix, isEmpty);
    });

    test('a disabled whitelist carries no suffixes, rather than "0"', () {
      // Reading 0 as data would build a whitelist of ["0"] and reject every
      // address that does not end in a zero — signup impossible, and for a
      // reason nothing on screen would explain.
      final config = XboardCommConfig.fromJson(const {
        'email_whitelist_suffix': 0,
      });
      expect(config.emailWhitelistSuffix, isEmpty);
    });

    test('an enabled whitelist is read as a list', () {
      final config = XboardCommConfig.fromJson(const {
        'email_whitelist_suffix': ['gmail.com', 'outlook.com'],
      });
      expect(config.emailWhitelistSuffix, ['gmail.com', 'outlook.com']);
    });

    test('a comma-separated whitelist is split', () {
      final config = XboardCommConfig.fromJson(const {
        'email_whitelist_suffix': 'gmail.com, outlook.com',
      });
      expect(config.emailWhitelistSuffix, ['gmail.com', 'outlook.com']);
    });

    test('flags are read whether sent as number, string or bool', () {
      expect(
        XboardCommConfig.fromJson(const {'is_email_verify': 1}).isEmailVerify,
        isTrue,
      );
      expect(
        XboardCommConfig.fromJson(const {'is_email_verify': '1'}).isEmailVerify,
        isTrue,
      );
      expect(
        XboardCommConfig.fromJson(const {'is_email_verify': true}).isEmailVerify,
        isTrue,
      );
      expect(
        XboardCommConfig.fromJson(const {'is_email_verify': 0}).isEmailVerify,
        isFalse,
      );
      expect(
        XboardCommConfig.fromJson(const {'is_email_verify': 'false'})
            .isEmailVerify,
        isFalse,
      );
    });

    test('an empty payload parses instead of throwing', () {
      // A panel that omits a field must not take the signup screen down with
      // it; every flag simply reads as off.
      final config = XboardCommConfig.fromJson(const {});
      expect(config.isEmailVerify, isFalse);
      expect(config.emailWhitelistSuffix, isEmpty);
    });

    test('an unexpected type anywhere still parses', () {
      final config = XboardCommConfig.fromJson(const {
        'is_email_verify': ['nonsense'],
        'is_invite_force': {'also': 'nonsense'},
        'email_whitelist_suffix': 12.5,
        'is_captcha': null,
      });
      expect(config.isEmailVerify, isFalse);
      expect(config.emailWhitelistSuffix, isEmpty);
    });
  });
}
