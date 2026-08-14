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

  Future<void> updateTraffic() async {
    final onlyStatisticsProxy = ref.read(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    final traffic = await coreController.getTraffic(onlyStatisticsProxy);
    ref.read(trafficsProvider.notifier).addTraffic(traffic);
    ref.read(totalTrafficProvider.notifier).value = await coreController
        .getTotalTraffic(onlyStatisticsProxy);
  }

  Future<void> autoCheckUpdate() async {
    // On mobile the app is distributed/updated through the app store (Google
    // Play), which prohibits in-app self-update prompts — only the desktop
    // builds check GitHub Releases.
    if (Platform.isAndroid || Platform.isIOS) return;
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

      // Locate the Windows installer asset (.exe) matching this machine's
      // architecture (releases ship both amd64 and arm64 installers), falling
      // back to any .exe if no arch-specific match is found.
      Map<String, dynamic>? exeAsset;
      final assets = data['assets'];
      if (assets is List) {
        final exeAssets = assets
            .whereType<Map<String, dynamic>>()
            .where((a) =>
                (a['name'] ?? '').toString().toLowerCase().endsWith('.exe'))
            .toList();
        final procArch =
            (Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '').toLowerCase();
        final archTag = procArch.contains('arm') ? 'arm64' : 'amd64';
        for (final a in exeAssets) {
          if ((a['name'] ?? '').toString().toLowerCase().contains(archTag)) {
            exeAsset = a;
            break;
          }
        }
        exeAsset ??= exeAssets.isNotEmpty ? exeAssets.first : null;
      }
      final sizeText = exeAsset != null && exeAsset['size'] is num
          ? ' (${_formatSize((exeAsset['size'] as num).toInt())})'
          : '';

      final context = globalState.navigatorKey.currentContext!;
      final textTheme = context.textTheme;
      final canInstall = exeAsset != null && Platform.isWindows;
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
          await _downloadAndLaunchInstaller(exeAsset);
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
    final dir = await appPath.homeDirPath;
    final savePath = '$dir${Platform.pathSeparator}$name';
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
    try {
      await Process.start(savePath, const [], mode: ProcessStartMode.detached);
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
