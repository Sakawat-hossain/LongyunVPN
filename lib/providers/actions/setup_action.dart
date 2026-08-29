part of '../action.dart';

@Riverpod(keepAlive: true)
class SetupAction extends _$SetupAction {
  Timer? _updateTimer;
  DateTime? startTime;

  bool get isStart => startTime != null && startTime!.isBeforeNow;

  @override
  void build() {}

  SetupParams get _setupParams {
    final selectedMap = ref.read(selectedMapProvider);
    final testUrl = ref.read(
      appSettingProvider.select((state) => state.testUrl),
    );
    return SetupParams(selectedMap: selectedMap, testUrl: testUrl);
  }

  void fullSetup() {
    if (!ref.read(initProvider)) return;
    ref.read(delayDataSourceProvider.notifier).value = {};
    applyProfile(force: true);
    ref.read(logsProvider.notifier).value = FixedList(500);
    ref.read(requestsProvider.notifier).value = FixedList(500);
  }

  /// How long to wait for the platform service to publish a run time after a
  /// start request, and how often to look while waiting.
  static const _startConfirmTimeout = Duration(seconds: 15);
  static const _startConfirmInterval = Duration(milliseconds: 300);

  /// Waits for the Android service to say it is actually running.
  ///
  /// The start call is answered before the tunnel exists — the method channel
  /// replies the moment the request is queued — so its return value proves
  /// nothing about whether establish() succeeded. A run time is published only
  /// once the service is genuinely up, and 0 (null here) is how it reports that
  /// it is not, which makes it the only honest signal available. Polling rather
  /// than reading once because the start runs on its own coroutine: checking
  /// immediately would call every slow-but-successful start a failure.
  Future<bool> _confirmStarted() async {
    final deadline = DateTime.now().add(_startConfirmTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await _updateStartTime();
      if (startTime != null) {
        return true;
      }
      await Future.delayed(_startConfirmInterval);
    }
    return false;
  }

  Future<void> _handleStart() async {
    // Start first, then believe the service rather than the clock. This used to
    // open with `startTime ??= DateTime.now()`, which set a start time whether
    // or not anything started — so a refused establish(), a missing options
    // payload, or a bind that timed out all produced a running timer over a
    // tunnel that was never created. Every request then failed on a timeout
    // with nothing on screen, and nothing in the log, to explain it.
    // Suspended means no start was requested at all, so there is nothing for
    // the confirmation below to wait on.
    final didRequestStart = !ref.read(suspendProvider);
    if (didRequestStart) {
      await coreController.startListener();
    }
    if (didRequestStart && Platform.isAndroid) {
      if (!await _confirmStarted()) {
        commonPrint.log(
          'the VPN service never reported a run time - the tunnel did not '
          'start; see the service log above for the reason',
          logLevel: LogLevel.error,
        );
        await handleStop();
        ref.read(runTimeProvider.notifier).value = null;
        return;
      }
    } else {
      startTime ??= DateTime.now();
    }
    //The local status must be updated when performing the run task
    ref.read(commonActionProvider.notifier).updateRunTime();
    ref.read(commonActionProvider.notifier).updateTraffic();
    _startPollingTimer();
  }

  void _startPollingTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(commonActionProvider.notifier).updateRunTime();
      ref.read(commonActionProvider.notifier).updateTraffic();
    });
  }

  /// Stops the 1-second traffic/runtime polling while the app is backgrounded —
  /// that data only feeds the visible UI. The tunnel keeps running natively and
  /// runtime is recomputed from [startTime] on resume, so nothing is lost.
  void pausePolling() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Resumes polling when the app returns to the foreground. No-op when not
  /// running or already polling.
  void resumePolling() {
    if (!isStart || _updateTimer != null) return;
    ref.read(commonActionProvider.notifier).updateRunTime();
    // The gap while backgrounded can be minutes long. Measuring across it would
    // report the average over that whole window as the current speed, so start
    // a fresh baseline and let the next tick produce the first real sample.
    ref.read(commonActionProvider.notifier).resetTrafficBaseline();
    ref.read(commonActionProvider.notifier).updateTraffic();
    _startPollingTimer();
  }

  Future _updateStartTime() async {
    startTime = await service?.getRunTime();
  }

  Future handleStop() async {
    startTime = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    await coreController.stopListener();
  }

  Future<void> initStatus() async {
    if (!globalState.needInitStatus) {
      commonPrint.log('init status cancel');
      return;
    }
    commonPrint.log('init status');
    if (system.isAndroid) {
      await _updateStartTime();
    }
    final status = isStart == true
        ? true
        : ref.read(appSettingProvider).autoRun;
    if (status == true) {
      await updateStatus(true, isInit: true);
    } else {
      await applyProfile(force: true);
    }
  }

  Future<void> updateStatus(bool isStart, {bool isInit = false}) async {
    if (isStart) {
      if (!isInit) {
        final res = await ref
            .read(coreActionProvider.notifier)
            .tryStartCore(true);
        if (res) return;
        if (!ref.read(initProvider)) return;
        await _handleStart();
        applyProfileDebounce(force: true, silence: true);
      } else {
        globalState.needInitStatus = false;
        ref.read(runTimeProvider.notifier).value = 0;
        try {
          await applyProfile(
            force: true,
            preloadInvoke: () async {
              await _handleStart();
            },
          );
        } catch (e) {
          // Resetting the run time is right, but throwing the reason away left
          // a failed connect with nothing behind it — not even a line in the
          // in-app log to say what went wrong.
          commonPrint.log(
            'start failed while applying profile: $e',
            logLevel: LogLevel.error,
          );
          ref.read(runTimeProvider.notifier).value = null;
        }
      }
    } else {
      // User-initiated stop: abort any in-flight auto-reconnect so we don't
      // fight the user's intent.
      ref.read(coreActionProvider.notifier).cancelReconnect();
      await handleStop();
      coreController.resetTraffic();
      // Speed is a delta against the previous totals, so the baseline has to go
      // with them — otherwise the first sample after the next start divides a
      // stale delta by a one-second interval and reports a spike.
      ref.read(commonActionProvider.notifier).resetTrafficBaseline();
      ref.read(trafficsProvider.notifier).clear();
      ref.read(totalTrafficProvider.notifier).value = const Traffic();
      ref.read(runTimeProvider.notifier).value = null;
      ref.read(checkIpNumProvider.notifier).add();
    }
  }

  Future<void> updateConfigDebounce() async {
    debouncer.call(FunctionTag.updateConfig, () async {
      await globalState.safeRun(() async {
        final updateParams = ref.read(updateParamsProvider);
        final res = await _requestAdmin(updateParams.tun.enable);
        if (res.isError) return;
        final realTunEnable = ref.read(realTunEnableProvider);
        final message = await coreController.updateConfig(
          updateParams.copyWith.tun(enable: realTunEnable),
        );
        if (message.isNotEmpty) throw message;
      });
    });
  }

  void tryCheckIp() {
    final isTimeout = ref.read(
      networkDetectionProvider.select(
        (state) => state.ipInfo == null && state.isLoading == false,
      ),
    );
    if (!isTimeout) return;
    ref.read(checkIpNumProvider.notifier).add();
  }

  void applyProfileDebounce({bool silence = false, bool force = false}) {
    debouncer.call(FunctionTag.applyProfile, (silence, force) {
      applyProfile(silence: silence, force: force);
    }, args: [silence, force]);
  }

  void changeMode(Mode mode) {
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mode: mode));
    if (mode == Mode.global) {
      ref
          .read(proxiesActionProvider.notifier)
          .updateCurrentGroupName(GroupName.GLOBAL.name);
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  void autoApplyProfile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyProfile();
    });
  }

  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    VoidCallback? preloadInvoke,
  }) async {
    await _setupConfig(
      force: force,
      silence: silence,
      preloadInvoke: preloadInvoke,
      onUpdated: () async {
        await ref.read(proxiesActionProvider.notifier).updateGroups();
        await ref.read(providersProvider.notifier).syncProviders();
      },
    );
  }

  Future<VM2<String, String>> getProfile({
    required SetupState setupState,
    required PatchClashConfig patchConfig,
  }) async {
    final profileId = setupState.profileId;
    if (profileId == null) return const VM2('', '');
    final defaultUA = globalState.packageInfo.ua;
    final networkVM2 = ref.read(
      networkSettingProvider.select(
        (state) => VM2(state.appendSystemDns, state.routeMode),
      ),
    );
    final overrideDns = ref.read(overrideDnsProvider);
    final appendSystemDns = networkVM2.a;
    final routeMode = networkVM2.b;
    final configMap = await coreController.getConfig(profileId);
    String? scriptContent;
    final List<Rule> addedRules = [];
    final List<ProxyGroup> proxyGroups = [];
    final List<Rule> rules = [];
    if (setupState.overwriteType == OverwriteType.script) {
      scriptContent = await setupState.script?.content;
    } else if (setupState.overwriteType == OverwriteType.standard) {
      addedRules.addAll(setupState.addedRules);
    } else {
      proxyGroups.addAll(setupState.proxyGroups);
      rules.addAll(setupState.rules);
    }
    final realPatchConfig = patchConfig.copyWith(
      tun: patchConfig.tun.getRealTun(routeMode),
    );
    Map<String, dynamic> rawConfig = configMap;
    if (scriptContent?.isNotEmpty == true) {
      rawConfig = await handleEvaluate(scriptContent!, rawConfig);
    }
    final directory = await appPath.profilesPath;
    final res = makeRealProfileTask(
      MakeRealProfileState(
        rules: rules,
        proxyGroups: proxyGroups,
        profilesPath: directory,
        profileId: profileId,
        rawConfig: rawConfig,
        realPatchConfig: realPatchConfig,
        overrideDns: overrideDns,
        appendSystemDns: appendSystemDns,
        addedRules: addedRules,
        defaultUA: defaultUA,
      ),
    );
    return res;
  }

  Future<String> getProfileWithId(int profileId) async {
    try {
      final setupState = await ref.read(setupStateProvider(profileId).future);
      final patchClashConfig = ref.read(patchClashConfigProvider);
      final res = await getProfile(
        setupState: setupState,
        patchConfig: patchClashConfig,
      );
      return res.a;
    } catch (e) {
      globalState.showNotifier(e.toString());
    }
    return '';
  }

  Future<Result<bool>> _requestAdmin(bool enableTun) async {
    final realTunEnable = ref.read(realTunEnableProvider);
    if (enableTun != realTunEnable && realTunEnable == false) {
      final code = await system.authorizeCore();
      switch (code) {
        case AuthorizeCode.success:
          await ref.read(coreActionProvider.notifier).restartCore();
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

  Future<void> _setupConfig({
    bool force = false,
    bool silence = false,
    VoidCallback? preloadInvoke,
    FutureOr Function()? onUpdated,
  }) async {
    var profile = ref.read(currentProfileProvider);
    final nextProfile = await profile?.checkAndUpdateAndCopy();
    if (nextProfile != null) {
      profile = nextProfile;
      ref.read(profilesProvider.notifier).put(nextProfile);
    }
    commonPrint.log('setup ===> ${profile?.id}');
    final patchConfig = ref.read(patchClashConfigProvider);
    final res = await _requestAdmin(patchConfig.tun.enable);
    if (res.isError) return;
    final realTunEnable = ref.read(realTunEnableProvider);
    final realPatchConfig = patchConfig.copyWith.tun(enable: realTunEnable);
    final setupState = await ref.read(setupStateProvider(profile?.id).future);
    if (system.isAndroid) {
      globalState.lastVpnState = ref.read(vpnStateProvider);
      final sharedState = ref.read(sharedStateProvider);
      preferences.saveShareState(sharedState);
    }
    final vm2 = await getProfile(
      setupState: setupState,
      patchConfig: realPatchConfig,
    );
    final yamlString = vm2.a;
    final yamlMd5 = vm2.b;
    if (yamlMd5 == globalState.lastConfigMd5 && force == false) {
      // The config is byte-identical, so there is nothing to hand the core —
      // but the caller still asked for a refresh. Returning here skipped
      // onUpdated, which is what reloads the proxy groups, so once the server
      // list had come up empty no amount of pulling to refresh could ever
      // repopulate it: the md5 matched every time and the reload never ran.
      await onUpdated?.call();
      return;
    }
    await globalState.loadingRun(
      () async {
        final configFilePath = await appPath.configFilePath;
        await File(configFilePath).safeWriteAsString(yamlString);
        globalState.lastConfigMd5 = yamlMd5;
        final message = await coreController.setupConfig(
          setupState: setupState,
          params: _setupParams,
          preloadInvoke: preloadInvoke,
        );
        if (message.isNotEmpty && !message.endsWith('is empty')) {
          throw message;
        }
        ref.read(checkIpNumProvider.notifier).add();
        await onUpdated?.call();
      },
      silence: true,
      tag: !silence ? LoadingTag.proxies : null,
    );
  }
}
