import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/l10n/l10n.dart';
import 'package:longyunvpn/pages/reset_password.dart';

/// The reset form checks what the panel checks, before the panel is asked.
///
/// AuthForget validates `password|min:8` and `email_code|digits:6` server-side,
/// and only answers after the user has requested a code, waited for the mail,
/// and filled the whole form. Catching a short password at that point costs
/// someone the entire round trip — and a verification code they may only be
/// allowed to request once a minute.
void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: ResetPasswordPage(onBack: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldFor(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(TextFormField),
  );

  Future<void> fill(
    WidgetTester tester, {
    required String email,
    required String code,
    required String password,
    required String confirm,
  }) async {
    await tester.enterText(fieldFor('Email'), email);
    await tester.enterText(fieldFor('Verification Code'), code);
    await tester.enterText(fieldFor('New password'), password);
    await tester.enterText(fieldFor('Confirm Password'), confirm);
    await tester.pumpAndSettle();
  }

  testWidgets('offers every field the panel requires', (tester) async {
    await pumpPage(tester);

    expect(fieldFor('Email'), findsOneWidget);
    expect(fieldFor('Verification Code'), findsOneWidget);
    expect(fieldFor('New password'), findsOneWidget);
    expect(fieldFor('Confirm Password'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('rejects a password the panel would reject', (tester) async {
    await pumpPage(tester);
    // Seven characters: one short of AuthForget's min:8.
    await fill(
      tester,
      email: 'someone@example.com',
      code: '123456',
      password: 'short77',
      confirm: 'short77',
    );

    expect(find.text('Password must be at least 8 characters.'), findsWidgets);
  });

  testWidgets('rejects a confirmation that does not match', (tester) async {
    await pumpPage(tester);
    await fill(
      tester,
      email: 'someone@example.com',
      code: '123456',
      password: 'longenough1',
      confirm: 'longenough2',
    );

    expect(find.text('Passwords do not match.'), findsWidgets);
  });

  testWidgets('rejects a malformed address before asking for a code',
      (tester) async {
    await pumpPage(tester);
    await tester.enterText(fieldFor('Email'), 'not-an-address');
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsWidgets);
  });

  testWidgets('a valid form shows no complaints', (tester) async {
    await pumpPage(tester);
    await fill(
      tester,
      email: 'someone@example.com',
      code: '123456',
      password: 'longenough1',
      confirm: 'longenough1',
    );

    expect(find.text('Password must be at least 8 characters.'), findsNothing);
    expect(find.text('Passwords do not match.'), findsNothing);
    expect(find.text('Enter a valid email address.'), findsNothing);
  });
}
