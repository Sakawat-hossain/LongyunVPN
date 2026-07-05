import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  Widget _getDeveloperList(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return generateSectionV2(
      title: appLocalizations.options,
      items: [
        ListItem(
          title: Text(appLocalizations.messageTest),
          minVerticalPadding: 12,
          onTap: () {
            context.showNotifier(appLocalizations.messageTestTip);
          },
        ),
        ListItem(
          title: Text(appLocalizations.logsTest),
          minVerticalPadding: 12,
          onTap: () {
            for (int i = 0; i < 1000; i++) {
              globalState.container
                  .read(logsProvider.notifier)
                  .add(
                    Log.app(
                      '[$i]${utils.generateRandomString(maxLength: 200, minLength: 20)}',
                    ),
                  );
            }
          },
        ),
        if (globalState.isPre)
          ListItem(
            title: Text(appLocalizations.crashTest),
            minVerticalPadding: 12,
            onTap: () async {
              final res = await globalState.showMessage(
                message: TextSpan(text: appLocalizations.confirmForceCrashCore),
              );
              if (res != true) {
                return;
              }
              coreController.crash();
            },
          ),
        ListItem(
          title: Text(appLocalizations.clearData),
          minVerticalPadding: 12,
          onTap: () async {
            final res = await globalState.showMessage(
              message: TextSpan(text: appLocalizations.confirmClearAllData),
            );
            if (res != true) {
              return;
            }
            await globalState.container
                .read(storeActionProvider.notifier)
                .handleClear();
          },
        ),
        // ListItem(
        //   title: Text(appLocalizations.loadTest),
        //   minVerticalPadding: 12,
        //   onTap: () {
        //     ref.read(loadingProvider.notifier).value = !ref.read(
        //       loadingProvider,
        //     );
        //   },
        // ),
        ListItem(
          title: Text(appLocalizations.pruneCache),
          minVerticalPadding: 12,
          onTap: () async {
            await globalState.container
                .read(storeActionProvider.notifier)
                .shakingStore();
          },
        ),
        // The exact mihomo config the app hands the core (written on setup at
        // action.dart:_setupConfig). Handy for diffing against another client's
        // generated config for the same subscription.
        ListItem(
          title: Text(appLocalizations.copyEffectiveConfig),
          minVerticalPadding: 12,
          onTap: () async {
            final content = await _readEffectiveConfig();
            if (content == null) {
              if (context.mounted) {
                context.showNotifier(appLocalizations.noActiveProfileImport);
              }
              return;
            }
            await Clipboard.setData(ClipboardData(text: content));
            if (context.mounted) {
              context.showNotifier(appLocalizations.copySuccess);
            }
          },
        ),
        ListItem(
          title: Text(appLocalizations.exportEffectiveConfig),
          minVerticalPadding: 12,
          onTap: () async {
            final path = await appPath.configFilePath;
            if (!await File(path).exists()) {
              if (context.mounted) {
                context.showNotifier(appLocalizations.noActiveProfileImport);
              }
              return;
            }
            final saved = await picker.saveFileWithPath(
              'longyunvpn-effective-config.yaml',
              path,
            );
            if (saved != null && context.mounted) {
              context.showNotifier(appLocalizations.exportSuccess);
            }
          },
        ),
        // Persistent crash log (uncaught framework/async errors + init
        // failures), for diagnosing field crashes.
        ListItem(
          title: Text(appLocalizations.exportCrashLog),
          minVerticalPadding: 12,
          onTap: () async {
            final path = await CrashLog.filePath();
            if (path == null || !await File(path).exists()) {
              if (context.mounted) {
                context.showNotifier(appLocalizations.noCrashLog);
              }
              return;
            }
            final saved = await picker.saveFileWithPath(
              'longyunvpn-crash.log',
              path,
            );
            if (saved != null && context.mounted) {
              context.showNotifier(appLocalizations.exportSuccess);
            }
          },
        ),
      ],
    );
  }

  Future<String?> _readEffectiveConfig() async {
    final file = File(await appPath.configFilePath);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      appSettingProvider.select((state) => state.developerMode),
    );
    return BaseScaffold(
      title: appLocalizations.developerMode,
      body: SingleChildScrollView(
        padding: baseInfoEdgeInsets,
        child: Column(
          children: [
            CommonCard(
              type: CommonCardType.filled,
              radius: 18,
              child: ListItem.switchItem(
                padding: const EdgeInsets.only(left: 16, right: 16),
                title: Text(appLocalizations.developerMode),
                delegate: SwitchDelegate(
                  value: enable,
                  onChanged: (value) {
                    ref
                        .read(appSettingProvider.notifier)
                        .update(
                          (state) => state.copyWith(developerMode: value),
                        );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _getDeveloperList(context, ref),
          ],
        ),
      ),
    );
  }
}
