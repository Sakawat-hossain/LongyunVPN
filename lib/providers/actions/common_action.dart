part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  @override
  void build() {}

  void updateStart() {
    ref
        .read(setupActionProvider.notifier)
        .updateStatus(!ref.read(isStartProvider));
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  void updateRunTime() {
    final startTime = ref.read(setupActionProvider.notifier).startTime;
    if (startTime != null) {
      final startTimeStamp = startTime.millisecondsSinceEpoch;
      final nowTimeStamp = DateTime.now().millisecondsSinceEpoch;
      ref.read(runTimeProvider.notifier).value = nowTimeStamp - startTimeStamp;
    } else {
      ref.read(runTimeProvider.notifier).value = null;
    }
  }

  final _rateMeter = TrafficRateMeter();
  bool _sampling = false;

  /// Samples throughput once and appends it to the speed history.
  ///
  /// Speed is computed from the cumulative counters and the measured interval,
  /// not from the core's own per-second figure. That figure is a snapshot the
  /// core refreshes on a one-second ticker of its own, and this poll runs on a
  /// separate one-second timer, so the two clocks drift against each other. As
  /// the phase slides, one poll reads a snapshot it has already reported and
  /// the next skips a whole second that is never reported at all — a duplicate
  /// then a gap, over and over. On a perfectly steady download that alone draws
  /// a line that keeps stepping up and down, which is what the speed graph was
  /// doing. Dividing a counter delta by the time actually elapsed cannot alias:
  /// nothing is double-counted and nothing is dropped, however the two timers
  /// happen to line up, and a late poll is corrected by its own longer interval
  /// rather than showing up as a spike.
  Future<void> updateTraffic() async {
    // One sample at a time. Timer.periodic does not wait for the previous run,
    // and on a slow device two overlapping calls would take their deltas from
    // the same baseline and each report roughly half the real speed.
    if (_sampling) return;
    _sampling = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final total = await coreController.getTotalTraffic(onlyStatisticsProxy);
      ref.read(totalTrafficProvider.notifier).value = total;

      final speed = _rateMeter.sample(
        total,
        onlyProxy: onlyStatisticsProxy,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      // Null means there was no interval worth measuring across — the first
      // sample after a reset, or a change of accounting scope. Reporting a
      // figure there would be worse than reporting nothing.
      if (speed == null) return;
      ref.read(trafficsProvider.notifier).addTraffic(speed);
    } finally {
      _sampling = false;
    }
  }

  /// Drops the speed baseline so the next sample starts a fresh interval.
  void resetTrafficBaseline() => _rateMeter.reset();

  Future<void> autoCheckUpdate() async {
    // Android ships its APKs from GitHub Releases, not Play, so it checks for
    // updates like the desktop builds do. (If this app is ever listed on Play,
    // this check and the REQUEST_INSTALL_PACKAGES permission in the manifest
    // both have to go — Play forbids self-updating.) iOS has no sideload path
    // at all, so there is nothing it could do with an update it found.
    if (Platform.isIOS) return;
    if (!ref.read(appSettingProvider).autoCheckUpdate) return;
    final res = await request.checkForUpdate();
    // Automatic checks honor a previously-skipped version so the user isn't
    // re-nagged about it (a manual check from Settings bypasses this).
    final tagName = res?['tag_name']?.toString() ?? '';
    if (tagName.isNotEmpty &&
        await preferences.getSkippedUpdateVersion() == tagName) {
      return;
    }
    checkUpdateResultHandle(data: res);
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final l = currentAppLocalizations;
      final tagName = data['tag_name']?.toString() ?? '';
      final body = data['body'];
      final submits = utils.parseReleaseBody(body);
      final currentVersion = globalState.packageInfo.version;

      final context = globalState.navigatorKey.currentContext!;
      final textTheme = context.textTheme;

      final installerAsset = await _installerAssetFor(data['assets']);
      final sizeText = installerAsset != null && installerAsset['size'] is num
          ? ' (${_formatSize((installerAsset['size'] as num).toInt())})'
          : '';
      final canInstall = installerAsset != null;
      final res = await globalState.showMessage(
        title: l.discoverNewVersion,
        message: TextSpan(
          style: textTheme.bodyMedium,
          children: [
            TextSpan(text: '${l.currentVersion}: v$currentVersion\n'),
            TextSpan(
              text: '${l.latestVersion}: $tagName$sizeText\n\n',
              style: textTheme.titleSmall,
            ),
            for (final submit in submits) TextSpan(text: '• $submit \n'),
          ],
        ),
        confirmText: canInstall ? l.updateNow : l.goDownload,
        cancelText: isUser ? null : l.skipThisVersion,
      );
      if (res == true) {
        if (canInstall) {
          await _downloadAndLaunchInstaller(installerAsset);
        } else {
          _openReleasesPage();
        }
      } else if (!isUser && res == false && tagName.isNotEmpty) {
        // "Skip this version": suppress only this tag on future auto-checks —
        // auto-update stays on (users can still turn it off in Settings).
        await preferences.setSkippedUpdateVersion(tagName);
      }
    } else if (isUser) {
      globalState.showMessage(
        title: currentAppLocalizations.checkUpdate,
        message: TextSpan(text: currentAppLocalizations.checkUpdateError),
      );
    }
  }

  void _openReleasesPage() {
    launchUrl(Uri.parse('https://github.com/$repository/releases/latest'));
  }

  /// Picks the release asset that can update *this* build in place: the Windows
  /// installer for the running architecture, the APK for the device's ABI, or
  /// the AppImage when the app is running as one.
  ///
  /// Returns null where there is no in-app install path — macOS, Linux deb/rpm
  /// installs, and anywhere the right asset simply isn't in the release — and
  /// the dialog then offers the releases page instead of an install button.
  Future<Map<String, dynamic>?> _installerAssetFor(Object? assets) async {
    if (assets is! List) return null;
    final candidates = assets.whereType<Map<String, dynamic>>();
    String nameOf(Map<String, dynamic> a) =>
        (a['name'] ?? '').toString().toLowerCase();

    if (Platform.isWindows) {
      final exeAssets = candidates
          .where((a) => nameOf(a).endsWith('.exe'))
          .toList();
      if (exeAssets.isEmpty) return null;
      // Releases ship both amd64 and arm64 installers. An arm64 machine runs
      // the amd64 build under emulation, so falling back to whatever .exe
      // exists still produces a working install.
      final procArch = (Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '')
          .toLowerCase();
      final archTag = procArch.contains('arm') ? 'arm64' : 'amd64';
      return exeAssets.firstWhere(
        (a) => nameOf(a).contains(archTag),
        orElse: () => exeAssets.first,
      );
    }

    if (Platform.isAndroid) {
      final apkAssets = candidates
          .where((a) => nameOf(a).endsWith('.apk'))
          .toList();
      if (apkAssets.isEmpty) return null;
      // Releases ship one APK per ABI, and unlike Windows there is no viable
      // fallback: an APK for the wrong ABI carries the wrong native core, so
      // if this device's ABI isn't published we send the user to the releases
      // page rather than install something that can't run.
      final abi = (await app?.getAbi() ?? '').toLowerCase();
      if (abi.isEmpty) return null;
      // Bounded match so a 32-bit "x86" device doesn't claim the "x86_64" APK.
      final abiPattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(abi)}([^a-z0-9_]|\$)',
      );
      for (final asset in apkAssets) {
        if (abiPattern.hasMatch(nameOf(asset))) return asset;
      }
      return null;
    }

    if (Platform.isLinux) {
      // Only an AppImage can replace itself. deb and rpm installs belong to the
      // package manager and need root, so those users get the releases page and
      // their distro's normal upgrade path instead. APPIMAGE is set by the
      // AppImage runtime and holds the path of the running image, so its
      // absence also covers running from source.
      final appImagePath = _runningAppImagePath();
      if (appImagePath == null) return null;
      final images = candidates
          .where((a) => nameOf(a).endsWith('.appimage'))
          .toList();
      if (images.isEmpty) return null;
      // Releases only build linux-amd64 today, but match the running
      // architecture anyway so an arm64 image can never be handed to an amd64
      // machine once one is published.
      final archTag = Platform.version.contains('linux_arm64')
          ? 'arm64'
          : 'amd64';
      for (final image in images) {
        if (nameOf(image).contains(archTag)) return image;
      }
      return null;
    }

    return null;
  }

  /// Path of the running AppImage, or null when this isn't one (a deb/rpm
  /// install, running from source, or any non-Linux platform).
  String? _runningAppImagePath() {
    if (!Platform.isLinux) return null;
    final path = Platform.environment['APPIMAGE'];
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// Directory containing [path]. Only ever used for the Linux AppImage path,
  /// so a '/' split is enough and saves pulling package:path into this library.
  String _parentDirOf(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '/' : path.substring(0, index);
  }

  /// Removes installers left behind by previous updates. They are tens of
  /// megabytes each and nothing else ever cleans them up, so without this the
  /// data directory grows by one installer per release. Only ever touches the
  /// two extensions the updater itself writes.
  Future<void> _cleanStaleDownloads(String dirPath, String keepPath) async {
    try {
      await for (final entity in Directory(dirPath).list(followLinks: false)) {
        if (entity is! File) continue;
        if (entity.path == keepPath) continue;
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.exe') || lower.endsWith('.apk')) {
          await entity.safeDelete();
        }
      }
    } catch (_) {
      // Best-effort housekeeping — never let it block an update.
    }
  }

  String _formatSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  /// Downloads the release installer and launches it. User settings, session
  /// and profiles survive because they live in the app's data directory, which
  /// the installer doesn't touch. Falls back to the releases page on failure.
  Future<void> _downloadAndLaunchInstaller(Map<String, dynamic> asset) async {
    final l = currentAppLocalizations;
    final url = asset['browser_download_url']?.toString();
    final name = asset['name']?.toString();
    if (url == null || name == null) {
      _openReleasesPage();
      return;
    }
    // Save to the app's private data dir rather than the world-writable system
    // temp, so no other user/process can swap the file between verification and
    // launch (closes the TOCTOU window).
    // An AppImage is replaced by an atomic rename, and rename only works within
    // a single filesystem — so that download lands beside the image it will
    // replace rather than in the app's data directory.
    final appImagePath = _runningAppImagePath();
    final dir = appImagePath != null
        ? _parentDirOf(appImagePath)
        : await appPath.homeDirPath;
    final savePath = '$dir${Platform.pathSeparator}$name';
    if (appImagePath == null) {
      // Only sweep our own data directory. The AppImage's directory belongs to
      // the user and may hold anything.
      await _cleanStaleDownloads(dir, savePath);
    }
    // Show real progress rather than an indeterminate spinner: the installer is
    // tens of megabytes, and the old blocking "please wait" gave no sign of
    // life and no way to back out. downloadFile never throws — it returns false
    // after retrying (or immediately, if cancelled), so the user never sees a
    // raw socket error.
    final cancelToken = CancelToken();
    final ok = await globalState.showCommonDialog<bool>(
      dismissible: false,
      child: UpdateProgressDialog(
        url: url,
        savePath: savePath,
        cancelToken: cancelToken,
      ),
    );
    if (ok != true) {
      // Cancelling is a deliberate choice — don't nag with an error or push the
      // user to the browser; just leave them where they were.
      if (!cancelToken.isCancelled) {
        globalState.showNotifier(l.updateDownloadFailed);
        _openReleasesPage();
      }
      return;
    }
    // Never execute an unverified binary. GitHub publishes a server-side SHA256
    // for each asset ("sha256:<hex>"); the download must match it. If the hash
    // differs (tampering / MITM / a truncated file), or GitHub gave us no digest
    // to check against, delete the file and hand off to the browser instead of
    // launching it.
    final expectedSha = _expectedSha256(asset['digest']);
    final actualSha = await _sha256OfFile(savePath);
    if (expectedSha == null ||
        actualSha == null ||
        actualSha.toLowerCase() != expectedSha.toLowerCase()) {
      commonPrint.log(
        'installer verification failed: expected=$expectedSha actual=$actualSha',
        logLevel: LogLevel.warning,
      );
      await File(savePath).safeDelete();
      globalState.showNotifier(l.updateVerificationFailed);
      _openReleasesPage();
      return;
    }
    if (appImagePath != null) {
      // Replace the running AppImage with the verified one and relaunch. The
      // rename is atomic and the running process keeps the old inode open, so
      // this is safe to do to ourselves; if any step fails, the image on disk
      // is either untouched or already fully replaced — never half-written.
      // Settings and profiles live in ~/.local/share, which this doesn't touch.
      try {
        // Dart can't chmod, and an AppImage that isn't executable won't start.
        final chmod = await Process.run('chmod', ['+x', savePath]);
        if (chmod.exitCode != 0) {
          throw ProcessException('chmod', ['+x', savePath], chmod.stderr
              .toString());
        }
        await File(savePath).rename(appImagePath);
      } catch (e) {
        // Read-only mount, an image owned by another user, /tmp mounted noexec:
        // nothing has changed, so leave the user on the working version.
        commonPrint.log(
          'AppImage self-update failed: $e',
          logLevel: LogLevel.warning,
        );
        await File(savePath).safeDelete();
        globalState.showNotifier(l.updateDownloadFailed);
        _openReleasesPage();
        return;
      }
      globalState.showNotifier(l.installerLaunched);
      // Start the new image before quitting: the single-instance lock retries
      // for six seconds and this process force-exits after three, so the new
      // instance waits out the handover exactly as it does after "Clear Data".
      try {
        await Process.start(
          appImagePath,
          const [],
          mode: ProcessStartMode.detached,
        );
      } catch (e) {
        // The update is already installed at this point — the user just has to
        // start it themselves, so don't tear the running app down.
        commonPrint.log(
          'AppImage relaunch failed: $e',
          logLevel: LogLevel.warning,
        );
        return;
      }
      await ref.read(systemActionProvider.notifier).handleExit(true);
      return;
    }

    if (Platform.isAndroid) {
      // Android does the installing itself: hand the verified APK to the system
      // package installer, which shows its own confirmation screen. It upgrades
      // the app in place, so settings, profiles and the session survive, and it
      // only accepts a package signed with the same key — a tampered or
      // differently-signed APK is rejected by the OS, on top of the SHA256
      // check above.
      final handedOff = await app!.installApk(savePath);
      if (!handedOff) {
        // Either "install unknown apps" isn't granted for us — in which case
        // the plugin has just opened the settings screen that grants it — or
        // the handover failed outright. The running app is untouched either
        // way, and the verified APK stays on disk so a retry doesn't have to
        // download it again.
        globalState.showNotifier(l.installPermissionRequired);
      }
      return;
    }
    try {
      // One click, not two. The installer used to open its wizard and wait for
      // the user to click through it; run it silently instead so the update
      // completes on its own.
      //
      // /SILENT keeps the progress window (the app is about to be closed and
      // reopened, so some visible sign that something is happening is worth
      // keeping) while skipping every page that needs an answer.
      // /SUPPRESSMSGBOXES answers the prompts that would otherwise block a
      // silent run, and /NORESTART stops setup deciding to reboot the machine.
      //
      // Setup closes this app itself and relaunches it from its [Run] section,
      // so nothing here needs to exit or restart anything. Deliberately NOT
      // exiting first: if the user declines the elevation prompt, the update
      // simply doesn't happen and they are left with a working app.
      await Process.start(savePath, const [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
      ], mode: ProcessStartMode.detached);
      globalState.showNotifier(l.installerLaunched);
    } catch (_) {
      globalState.showNotifier(l.updateDownloadFailed);
      _openReleasesPage();
    }
  }

  /// Parses GitHub's asset `digest` field (`sha256:<hex>`) into the bare hex
  /// hash, or null when absent or not a SHA256 digest.
  String? _expectedSha256(Object? digest) {
    if (digest is! String) return null;
    final parts = digest.split(':');
    if (parts.length == 2 && parts[0].toLowerCase() == 'sha256') {
      final hex = parts[1].trim();
      return hex.isNotEmpty ? hex : null;
    }
    return null;
  }

  /// Streams [path] through SHA256 (chunked — never loads the whole installer
  /// into memory). Returns the lowercase hex digest, or null on read error.
  Future<String?> _sha256OfFile(String path) async {
    try {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }
}
