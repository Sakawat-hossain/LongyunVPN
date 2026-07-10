part of '../action.dart';

@Riverpod(keepAlive: true)
class CoreAction extends _$CoreAction {
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectDelaysSeconds = [2, 4, 8, 16, 30];

  @override
  void build() {}

  /// Cancels any pending auto-reconnect and resets the backoff. Call on a
  /// user-initiated stop or after a successful (re)connect.
  void cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  /// Backoff delay for reconnect [attempt] (0-based), or null once the attempt
  /// cap is reached (i.e. give up). Pure — the backoff *policy*, separated from
  /// the scheduling mechanism so it can be unit-tested.
  static Duration? reconnectDelayFor(int attempt) {
    if (attempt >= _maxReconnectAttempts) return null;
    final index = attempt.clamp(0, _reconnectDelaysSeconds.length - 1);
    return Duration(seconds: _reconnectDelaysSeconds[index]);
  }

  /// Schedules an auto-reconnect after an *unexpected* core drop, with capped
  /// exponential backoff. No-op unless the user still intends to be connected
  /// (not stopped, not suspended). Gives up after [_maxReconnectAttempts].
  void scheduleReconnect() {
    if (!ref.read(isStartProvider) || ref.read(suspendProvider)) {
      cancelReconnect();
      return;
    }
    final delay = reconnectDelayFor(_reconnectAttempts);
    if (delay == null) {
      cancelReconnect();
      globalState.showNotifier(
        currentAppLocalizations.reconnectFailed,
        actionState: MessageActionState(
          actionText: currentAppLocalizations.retry,
          action: () {
            cancelReconnect();
            ref.read(setupActionProvider.notifier).updateStatus(true);
          },
        ),
      );
      return;
    }
    _reconnectAttempts++;
    // Surface the recovery in the UI (the start button already renders this).
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      // The user may have stopped or suspended while we were waiting.
      if (!ref.read(isStartProvider) || ref.read(suspendProvider)) {
        cancelReconnect();
        return;
      }
      try {
        await restartCore(true);
      } catch (e) {
        commonPrint.log(
          'auto-reconnect attempt failed: $e',
          logLevel: LogLevel.warning,
        );
      }
      if (ref.read(coreStatusProvider) == CoreStatus.connected) {
        cancelReconnect();
      } else {
        scheduleReconnect();
      }
    });
  }

  Future<void> initCore() async {
    final isInit = await coreController.isInit;

    final version = ref.read(versionProvider);
    if (!isInit) {
      final res = await coreController.init(version);
      commonPrint.log('init result: $res');
    } else {
      await ref.read(proxiesActionProvider.notifier).updateGroups();
    }
  }

  Future<void> connectCore() async {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
    final result = await Future.wait([
      coreController.preload(),
      Future.delayed(const Duration(milliseconds: 300)),
    ]);
    final String message = result[0];
    if (message.isNotEmpty) {
      ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
      globalState.showNotifier(message);
      return;
    }
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  }

  Future<Result<bool>> requestAdmin(bool enableTun) async {
    final realTunEnable = ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          await restartCore();
          return Result.error('');
        case AuthorizeCode.none:
          break;
        case AuthorizeCode.error:
          enableTun = false;
          break;
      }
    }
    ref.read(realTunEnableProvider.notifier).value = enableTun;
    return Result.success(enableTun);
  }

  Future<void> restartCore([bool start = false]) async {
    final isDisconnected =
        ref.read(coreStatusProvider) == CoreStatus.disconnected;
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    await coreController.shutdown(!isDisconnected);
    await connectCore();
    await initCore();
    if (start || ref.read(isStartProvider)) {
      await ref
          .read(setupActionProvider.notifier)
          .updateStatus(true, isInit: true);
    } else {
      await ref.read(setupActionProvider.notifier).applyProfile(force: true);
    }
  }

  Future<bool> tryStartCore([bool start = false]) async {
    if (coreController.isCompleted) return false;
    await restartCore(start);
    return true;
  }

  void handleCoreDisconnected() {
    ref.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
  }
}
