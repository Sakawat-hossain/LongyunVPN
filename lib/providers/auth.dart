import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState {
  final AuthStatus status;
  final String? email;
  final XboardUserInfo? userInfo;
  final XboardSubscribeInfo? subscribeInfo;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.email,
    this.userInfo,
    this.subscribeInfo,
    this.isLoading = false,
    this.error,
  });

  /// True when the account has a usable plan: a plan is assigned and it either
  /// never expires (lifetime) or expires in the future. No plan, or an expired
  /// one, counts as inactive — those users are routed to Premium.
  bool get hasActiveSubscription {
    final info = userInfo;
    if (info == null || info.planId == null) return false;
    final expiredAt = info.expiredAt;
    // A dated plan is authoritative either way: the panel set that date, so
    // trust it without second-guessing the allowance (some panels express
    // "unlimited" as a zero transfer_enable).
    if (expiredAt != null) {
      return expiredAt * 1000 > DateTime.now().millisecondsSinceEpoch;
    }
    // No expiry is ambiguous. It means a lifetime plan, but it is also the
    // state of an account that was assigned a plan id without ever paying for
    // it — starting checkout is enough to get one. Treating that as Premium
    // handed out access for free, and the subscription it then imported had no
    // nodes in it, which is why the server list came up empty. A genuine
    // lifetime plan carries a data allowance; an unpaid one does not.
    return info.transferEnable > 0;
  }

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    XboardUserInfo? userInfo,
    XboardSubscribeInfo? subscribeInfo,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      userInfo: userInfo ?? this.userInfo,
      subscribeInfo: subscribeInfo ?? this.subscribeInfo,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> _restoreSession() async {
    final token = await preferences.getXboardToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.loggedOut);
      return;
    }
    xboardApi.setToken(token);
    // Restoring the session must survive a flaky or not-yet-ready network. On
    // a cold start (especially on mobile, or right after boot) the first call
    // often fails simply because connectivity isn't up yet, so retry briefly
    // before drawing any conclusion about the token.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        // Independent panel calls — fetch in parallel to halve cold-start
        // session-restore latency (the app is blocked on AuthStatus.unknown
        // until both return).
        final (userInfo, subscribeInfo) = await (
          xboardApi.getUserInfo(),
          xboardApi.getSubscribe(),
        ).wait;
        state = AuthState(
          status: AuthStatus.loggedIn,
          email: userInfo.email,
          userInfo: userInfo,
          subscribeInfo: subscribeInfo,
        );
        return;
      } catch (e) {
        lastError = e;
        if (_isAuthFailure(e)) break; // token really is dead — stop retrying
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }

    // Only destroy the saved token when the panel actually rejected it. The old
    // code cleared it on *any* error, so one failed request — no connectivity
    // at launch, a timeout, a 5xx — silently logged the user out and forced
    // them to type their credentials again. Keeping the token means the next
    // launch (or refresh) restores the session by itself.
    if (_isAuthFailure(lastError)) {
      await preferences.clearXboardToken();
      xboardApi.setToken(null);
    } else {
      commonPrint.log(
        'session restore failed, keeping token: $lastError',
        logLevel: LogLevel.warning,
      );
    }
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  /// True only when the panel answered and rejected the token (401/403), as
  /// opposed to the request never getting through.
  static bool _isAuthFailure(Object? error) {
    final wrapped = error is ParallelWaitError ? error.errors : error;
    if (wrapped is XboardApiException) return wrapped.isAuthFailure;
    if (wrapped is Iterable) {
      return wrapped.any(
        (e) => e is XboardApiException && e.isAuthFailure,
      );
    }
    return false;
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await xboardApi.login(email, password);
      await preferences.setXboardToken(token);
      // Sequential here (not parallelized) so a failing panel call surfaces its
      // own XboardApiException message to the login UI rather than a wrapped
      // ParallelWaitError.
      final userInfo = await xboardApi.getUserInfo();
      final subscribeInfo = await xboardApi.getSubscribe();
      state = AuthState(
        status: AuthStatus.loggedIn,
        email: userInfo.email,
        userInfo: userInfo,
        subscribeInfo: subscribeInfo,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password, {
    String? emailCode,
    String? inviteCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await xboardApi.register(
        email,
        password,
        emailCode: emailCode,
        inviteCode: inviteCode,
      );
      state = state.copyWith(isLoading: false);
      return await login(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await preferences.clearXboardToken();
    xboardApi.setToken(null);
    state = const AuthState(status: AuthStatus.loggedOut);
  }

  Future<void> refresh() async {
    if (state.status != AuthStatus.loggedIn) return;
    try {
      final (userInfo, subscribeInfo) = await (
        xboardApi.getUserInfo(),
        xboardApi.getSubscribe(),
      ).wait;
      state = state.copyWith(userInfo: userInfo, subscribeInfo: subscribeInfo);
    } catch (e) {
      // Non-fatal: keep the existing session/state, just note why a background
      // refresh didn't land.
      commonPrint.log('account refresh failed: $e');
    }
  }

  /// Regenerates the account's subscription URL on the panel and refreshes the
  /// local session so [AuthState.subscribeInfo] carries the new URL.
  ///
  /// Destructive account-wide — see [XboardApi.resetSubscribeUrl]. Returns the
  /// new URL so the caller can re-import the profile; throws on failure.
  Future<String> resetSubscribeUrl() async {
    final url = await xboardApi.resetSubscribeUrl();
    // Pull the panel's own view back down rather than trusting the returned
    // string alone, so plan/traffic stay consistent with the new credentials.
    await refresh();
    return url;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
