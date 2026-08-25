import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:longyunvpn/providers/app.dart';
import 'package:longyunvpn/providers/config.dart';
import 'package:longyunvpn/state.dart';
import 'package:longyunvpn/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(closeConnections: value));
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(onlyStatisticsProxy: value));
        },
      ),
    );
  }
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.minimizeOnExit),
      subtitle: Text(appLocalizations.minimizeOnExitDesc),
      delegate: SwitchDelegate(
        value: minimizeOnExit,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(minimizeOnExit: value));
        },
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      delegate: SwitchDelegate(
        value: autoLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(autoLaunch: value));
        },
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      delegate: SwitchDelegate(
        value: silentLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(silentLaunch: value));
        },
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      delegate: SwitchDelegate(
        value: autoRun,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(autoRun: value));
        },
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(hidden: value));
        },
      ),
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      delegate: SwitchDelegate(
        value: isAnimateToPage,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(isAnimateToPage: value));
        },
      ),
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      delegate: SwitchDelegate(
        value: openLogs,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(openLogs: value));
        },
      ),
    );
  }
}

/// Battery-optimisation exemption, surfaced where people actually look.
///
/// This control already existed, but only inside the On-Demand / SSID screen —
/// a page most users never open. That matters on OEM Android builds that kill
/// background processes aggressively (Vivo, Xiaomi, Huawei and friends): the
/// core runs in a separate `:remote` process, and when the system kills it the
/// app shows "Service disconnected" and sits on "Connecting..." forever. The
/// user has no way to guess that an exemption buried two screens away is the
/// remedy.
///
/// Deliberately a settings entry rather than a dialog in the connect path:
/// interrupting every connect on every Android device to warn about something
/// most of them do not suffer from would be worse than the problem.
class BatteryOptimizationItem extends ConsumerWidget {
  const BatteryOptimizationItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!system.isAndroid) return const SizedBox.shrink();
    final appLocalizations = context.appLocalizations;
    final disabled = ref.watch(batteryOptimizationDisableProvider);
    return ListItem(
      title: Text(appLocalizations.ignoreBatteryOptimization),
      subtitle: Text(
        disabled
            ? appLocalizations.batteryOptimizationStatusTip
            : appLocalizations.batteryOptimizationDesc,
      ),
      trailing: disabled
          ? const Icon(Icons.check_circle_outline)
          : const Icon(Icons.chevron_right),
      onTap: () {
        if (disabled) return;
        permissions.needWaitingBatteryOptimizationSettings = true;
        app?.openBatteryOptimizationSettings();
      },
    );
  }
}

/// Sends crash reports off the device. Hidden on Windows and Linux, where there
/// is no Firebase to send them to and crashes stay in the local log — showing a
/// dead switch there would be worse than showing none.
class CrashlyticsItem extends ConsumerWidget {
  const CrashlyticsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isFirebasePlatform) return const SizedBox.shrink();
    final appLocalizations = context.appLocalizations;
    final crashlytics = ref.watch(
      appSettingProvider.select((state) => state.crashlytics),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.crashlytics),
      subtitle: Text(appLocalizations.crashlyticsTip),
      delegate: SwitchDelegate(
        value: crashlytics,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(crashlytics: value));
          final analytics = ref.read(
            appSettingProvider.select((state) => state.analytics),
          );
          unawaited(
            FirebaseService.applyConsent(
              crashlytics: value,
              analytics: analytics,
            ),
          );
        },
      ),
    );
  }
}

/// Usage analytics — separate from crash reporting on purpose. Agreeing to send
/// a stack trace when the app dies is a different decision from agreeing to
/// continuous reporting of what you do in the app, and folding the second into a
/// switch labelled "crash analysis" would be quietly dishonest.
class AnalyticsItem extends ConsumerWidget {
  const AnalyticsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isFirebasePlatform) return const SizedBox.shrink();
    final appLocalizations = context.appLocalizations;
    final analytics = ref.watch(
      appSettingProvider.select((state) => state.analytics),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.analytics),
      subtitle: Text(appLocalizations.analyticsTip),
      delegate: SwitchDelegate(
        value: analytics,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(analytics: value));
          final crashlytics = ref.read(
            appSettingProvider.select((state) => state.crashlytics),
          );
          unawaited(
            FirebaseService.applyConsent(
              crashlytics: crashlytics,
              analytics: value,
            ),
          );
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      delegate: SwitchDelegate(
        value: autoCheckUpdate,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(autoCheckUpdate: value));
        },
      ),
    );
  }
}

/// Android kill switch. Apps can't toggle Android's "Block connections without
/// VPN" themselves, so this explains it and opens the system VPN settings where
/// the user enables Always-on VPN + lockdown.
class KillSwitchItem extends StatelessWidget {
  const KillSwitchItem({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return ListItem(
      leading: const Icon(Icons.gpp_good_outlined),
      title: Text(l.killSwitch),
      subtitle: Text(l.killSwitchDesc),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () async {
        final ok = await globalState.showMessage(
          title: l.killSwitch,
          message: TextSpan(text: l.killSwitchGuide),
          confirmText: l.openSettings,
        );
        if (ok == true) {
          await app?.openVpnSettings();
        }
      },
    );
  }
}

/// Desktop kill switch. Backed by the core's TUN `strict-route`, which blocks
/// any traffic that would bypass the tunnel while connected. Core-managed, so it
/// tears down when TUN stops — nothing can strand the user's network.
class DesktopKillSwitchItem extends ConsumerWidget {
  const DesktopKillSwitchItem({super.key});

  String _desc(BuildContext context) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'zh':
        return '开启后阻止任何绕过 VPN 隧道的流量（严格路由，需开启 TUN 模式）。';
      case 'ja':
        return 'VPN トンネルを迂回する通信を遮断します（厳格ルーティング、TUN モードが必要）。';
      case 'ru':
        return 'Блокирует трафик в обход VPN-туннеля (строгая маршрутизация; нужен режим TUN).';
      default:
        return 'Block any traffic that would leak outside the VPN tunnel '
            '(strict routing; requires TUN mode).';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final strictRoute = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.strictRoute),
    );
    return ListItem.switchItem(
      leading: const Icon(Icons.gpp_good_outlined),
      title: Text(l.killSwitch),
      subtitle: Text(_desc(context)),
      delegate: SwitchDelegate(
        value: strictRoute,
        onChanged: (bool value) {
          ref
              .read(patchClashConfigProvider.notifier)
              .update((state) => state.copyWith.tun(strictRoute: value));
        },
      ),
    );
  }
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [
      const MinimizeItem(),
      if (system.isDesktop) ...[
        const AutoLaunchItem(),
        const SilentLaunchItem(),
      ],
      const AutoRunItem(),
      if (system.isAndroid) ...[const HiddenItem()],
      const AnimateTabItem(),
      const OpenLogsItem(),
      const CloseConnectionsItem(),
      const UsageItem(),
      // Both are gated inside the widgets themselves (Firebase platforms only),
      // so macOS now gets them too rather than Android alone.
      const CrashlyticsItem(),
      const AnalyticsItem(),
      const BatteryOptimizationItem(),
      if (system.isAndroid) const KillSwitchItem(),
      if (system.isDesktop) const DesktopKillSwitchItem(),
      const AutoCheckUpdateItem(),
    ];
    return BaseScaffold(
      title: context.appLocalizations.application,
      body: ListView.separated(
        itemBuilder: (_, index) {
          final item = items[index];
          return item;
        },
        separatorBuilder: (_, _) {
          return const Divider(height: 0);
        },
        itemCount: items.length,
      ),
    );
  }
}
