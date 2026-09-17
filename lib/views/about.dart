import 'dart:async';
import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:longyunvpn/widgets/list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App identity (icon, name, version, description) shown at the top of Tools.
///
/// The action links that used to sit under a "More" heading inside this block
/// now live in [AboutLinks], which Tools renders at the bottom of the page:
/// nesting a section heading inside another section's content put two headers
/// in a row and doubled the list padding.
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});
  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer(
              builder: (_, ref, _) {
                return _DeveloperModeDetector(
                  child: Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            globalState.packageInfo.version,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                  onEnterDeveloperMode: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update((state) => state.copyWith(developerMode: true));
                    context.showNotifier(
                      appLocalizations.developerModeEnableTip,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];
    // No outer list padding here: this is embedded in the Tools list, which
    // already supplies its own. Adding it again indented the app info out of
    // line with every other row on the page.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }
}

/// Update check and community links, rendered at the bottom of Tools.
class AboutLinks extends StatelessWidget {
  const AboutLinks({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final l = context.appLocalizations;
    try {
      final data = await request.checkForUpdate();
      globalState.rootRef
          .read(commonActionProvider.notifier)
          .checkUpdateResultHandle(data: data, isUser: true);
    } catch (e) {
      // A check that could not be made is not the same as being up to date.
      // Routing the failure through checkUpdateResultHandle's null branch told
      // people on an old build they had the newest one, which is how a release
      // can sit unnoticed.
      globalState.showMessage(
        title: l.checkUpdate,
        message: TextSpan(text: '${l.checkUpdateFailed}\n$e'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    // Everywhere except iOS, which has no sideload path and so nothing it could
    // do with an update it found.
    //
    // This used to hide on Android too, on the reasoning that mobile updates
    // come from Play. The app is not on Play - it ships APKs from GitHub
    // Releases, the manifest carries REQUEST_INSTALL_PACKAGES, the updater
    // already picks the APK matching the device's ABI, and the automatic check
    // has been running on Android all along. Only this button was missing, so
    // an Android user could never ask the question themselves.
    //
    // It matters more than a convenience: a manual check passes isUser, which
    // is what bypasses "Skip this version". Without it, an Android user who
    // skipped a release could never be offered it again.
    final showUpdate = !Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUpdate) ...[
          ListItem(
            title: Text(appLocalizations.checkUpdate),
            trailing: const Icon(Icons.update),
            onTap: () => _checkUpdate(context),
          ),
          const Divider(height: 0),
        ],
        ListItem(
          title: Text(appLocalizations.visitWebsite),
          trailing: const Icon(Icons.launch),
          onTap: () => globalState.openUrl(appWebsiteUrl),
        ),
        const Divider(height: 0),
        ListItem(
          title: const Text('Telegram'),
          trailing: const Icon(Icons.launch),
          onTap: () => globalState.openUrl('https://t.me/longyunvpn'),
        ),
      ],
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
