import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/l10n/l10n.dart';
import 'package:longyunvpn/pages/login.dart';
import 'package:longyunvpn/providers/auth.dart';

/// "Remember me" has to mean something, and here it means whether the token is
/// written to secure storage. The app has always written it, so the box starts
/// checked: unchecking is opting out of a behaviour, not opting into one.
///
/// The default is the part worth pinning. If it ever flipped to false, every
/// existing user would be signed out on their next launch with nothing on
/// screen explaining why - and it would not show up until a restart, which is
/// exactly the kind of thing a test catches and a click-through does not.
void main() {
  Future<AuthState> pumpLogin(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => _StubAuth())],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return LoginPage(onSignUp: () {}, onForgotPassword: () {});
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container.read(authProvider);
  }

  testWidgets('offers the option, next to the way out', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('starts checked, so nothing changes for anyone', (tester) async {
    await pumpLogin(tester);

    final box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(
      box.value,
      isTrue,
      reason: 'an unchecked default would sign existing users out on restart',
    );
  });

  testWidgets('the label never breaks mid-word, at any phone width',
      (tester) async {
    // The first attempt put the label in a Flexible beside a Spacer. Both flex,
    // so they split the free space and the label was given less room than the
    // word "Remember" - which it broke in half rather than overflow.
    for (final width in [320.0, 360.0, 390.0, 412.0, 480.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpLogin(tester);

      final label = tester.renderObject<RenderBox>(find.text('Remember me'));
      final painted = tester.widget<Text>(find.text('Remember me'));
      final painter = TextPainter(
        text: TextSpan(text: painted.data, style: painted.style),
        textDirection: TextDirection.ltr,
      )..layout();

      expect(
        label.size.width,
        greaterThanOrEqualTo(painter.width - 0.5),
        reason: 'label squeezed narrower than its text at ${width}px',
      );
      expect(
        label.size.height,
        lessThan(painter.height * 1.6),
        reason: 'label wrapped to a second line at ${width}px',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the label toggles it, not just the box', (tester) async {
    await pumpLogin(tester);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
}

/// Stands in for the real notifier, which reaches the panel and the keystore on
/// construction. Nothing here signs in; these tests are about the control.
class _StubAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.loggedOut);
}
