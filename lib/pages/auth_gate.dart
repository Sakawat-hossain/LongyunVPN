import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home.dart';
import 'login.dart';
import 'reset_password.dart';
import 'signup.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  /// Which of the three signed-out forms is showing. Swapped with local
  /// state rather than Navigator routes for the reason below.
  _AuthForm _form = _AuthForm.login;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (!mounted) return;
      ref.read(profilesActionProvider.notifier).dedupeProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.status == AuthStatus.loggedIn &&
          previous?.status != AuthStatus.loggedIn) {
        if (next.hasActiveSubscription) {
          // Active plan: ensure the subscription profile exists, then leave the
          // user on the normal Home/dashboard. Only import when it's missing so
          // returning users aren't yanked to the Profiles tab every launch
          // (existing profiles auto-update on their own schedule).
          final subscribeUrl = next.subscribeInfo?.subscribeUrl;
          if (subscribeUrl != null && subscribeUrl.isNotEmpty) {
            final exists = ref
                .read(profilesProvider)
                .any((p) => p.url == subscribeUrl);
            if (!exists) {
              // Adopt, not just import: a profile left selected from another
              // account would otherwise stay the one in use.
              ref
                  .read(profilesActionProvider.notifier)
                  .adoptAccountProfile(subscribeUrl)
                  .then((_) {
                    ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.dashboard);
                  });
            }
          }
        } else {
          // No active plan (new or expired): route straight to Premium so the
          // user can buy a package. Don't force this on users with a plan.
          ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.premium);
        }
      }
    });

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.loggedOut:
        // Login/SignUp are swapped here via local state rather than
        // Navigator push/pop, since this widget already swaps in HomePage
        // reactively when authState flips to loggedIn — pushing a Navigator
        // route for SignUp would race with that swap on the same route
        // stack and could leave the engine mid-transition (observed as a
        // black screen on Windows).
        return switch (_form) {
          _AuthForm.signUp => SignUpPage(
            onBack: () => setState(() => _form = _AuthForm.login),
          ),
          _AuthForm.resetPassword => ResetPasswordPage(
            onBack: () => setState(() => _form = _AuthForm.login),
          ),
          _AuthForm.login => LoginPage(
            onSignUp: () => setState(() => _form = _AuthForm.signUp),
            onForgotPassword: () =>
                setState(() => _form = _AuthForm.resetPassword),
          ),
        };
      case AuthStatus.loggedIn:
        return const HomePage();
    }
  }
}

/// The forms available before sign-in.
enum _AuthForm { login, signUp, resetPassword }
