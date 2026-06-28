import 'package:fl_clash/common/common.dart';
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
    if (expiredAt == null) return true;
    return expiredAt * 1000 > DateTime.now().millisecondsSinceEpoch;
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
    try {
      final userInfo = await xboardApi.getUserInfo();
      final subscribeInfo = await xboardApi.getSubscribe();
      state = AuthState(
        status: AuthStatus.loggedIn,
        email: userInfo.email,
        userInfo: userInfo,
        subscribeInfo: subscribeInfo,
      );
    } catch (_) {
      await preferences.clearXboardToken();
      xboardApi.setToken(null);
      state = const AuthState(status: AuthStatus.loggedOut);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await xboardApi.login(email, password);
      await preferences.setXboardToken(token);
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
      final userInfo = await xboardApi.getUserInfo();
      final subscribeInfo = await xboardApi.getSubscribe();
      state = state.copyWith(userInfo: userInfo, subscribeInfo: subscribeInfo);
    } catch (_) {}
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
