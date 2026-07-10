import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

double get listHeaderHeight {
  final measure = globalState.measure;
  return 20 + measure.titleMediumHeight + 4 + measure.bodyMediumHeight + 2;
}

double getItemHeight(ProxyCardType proxyCardType) {
  final measure = globalState.measure;
  final baseHeight =
      16 + measure.bodyMediumHeight * 2 + measure.bodySmallHeight + 8 + 4;
  return switch (proxyCardType) {
    ProxyCardType.expand => baseHeight + measure.labelSmallHeight + 6,
    ProxyCardType.shrink => baseHeight,
    ProxyCardType.min => baseHeight - measure.bodyMediumHeight,
  };
}

List<Group> getCurrentGroups() {
  return globalState.container.read(currentGroupsStateProvider).value;
}

List<Group> getGroups() {
  return globalState.container.read(groupsProvider);
}

String? getCurrentGroupName() {
  return globalState.container.read(
    currentProfileProvider.select((state) => state?.currentGroupName),
  );
}

void updateCurrentGroupName(String groupName) {
  globalState.container
      .read(proxiesActionProvider.notifier)
      .updateCurrentGroupName(groupName);
}

void updateCurrentUnfoldSet(Set<String> value) {
  globalState.container
      .read(proxiesActionProvider.notifier)
      .updateCurrentUnfoldSet(value);
}

Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) async {
  final ref = globalState.container;
  final groups = getGroups();
  final selectedMap = ref.read(
    currentProfileProvider.select((state) => state?.selectedMap ?? {}),
  );
  final state = computeRealSelectedProxyState(
    proxy.name,
    groups: groups,
    selectedMap: selectedMap,
  );
  final currentTestUrl = state.testUrl.takeFirstValid([
    ref.read(realTestUrlProvider(testUrl)),
  ]);
  if (state.proxyName.isEmpty) {
    return;
  }
  ref
      .read(proxiesActionProvider.notifier)
      .setDelay(Delay(url: currentTestUrl, name: state.proxyName, value: 0));
  ref
      .read(proxiesActionProvider.notifier)
      .setDelay(await coreController.getDelay(currentTestUrl, state.proxyName));
}

Future<void> delayTest(List<Proxy> proxies, [String? testUrl]) async {
  final delayProxies = proxies.map<Future>((proxy) async {
    await proxyDelayTest(proxy, testUrl);
  }).toList();

  final batchesDelayProxies = delayProxies.batch(8);
  for (final batchDelayProxies in batchesDelayProxies) {
    await Future.wait(batchDelayProxies);
  }
  globalState.container.read(sortNumProvider.notifier).add();
}

/// Built-in pseudo proxies that Quick Connect must never select as "fastest".
const _quickConnectExclude = {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
  'GLOBAL',
};

/// The name of the fastest proxy in [proxies] — the lowest *positive* delay per
/// [delayOf] — skipping [exclude]d names. Null when none has a usable latency.
/// Pure, so the selection logic can be unit-tested independently of the UI.
String? fastestProxyName(
  List<Proxy> proxies,
  int? Function(String name) delayOf, {
  Set<String> exclude = const {},
}) {
  String? best;
  var bestDelay = 0;
  for (final proxy in proxies) {
    if (exclude.contains(proxy.name)) continue;
    final delay = delayOf(proxy.name);
    if (delay == null || delay <= 0) continue;
    if (best == null || delay < bestDelay) {
      best = proxy.name;
      bestDelay = delay;
    }
  }
  return best;
}

/// Tests every node in [group] and switches the group's selection to the
/// fastest responder. Returns the selected proxy name, or null if no node
/// responded. Only meaningful for a manually-selectable group.
Future<String?> quickSelectFastest(Group group) async {
  await delayTest(group.all, group.testUrl);
  final ref = globalState.container;
  final fastest = fastestProxyName(
    group.all,
    (name) => ref.read(delayProvider(proxyName: name, testUrl: group.testUrl)),
    exclude: _quickConnectExclude,
  );
  if (fastest != null) {
    await ref
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: group.name, proxyName: fastest);
  }
  return fastest;
}

double getScrollToSelectedOffset({
  required String groupName,
  required List<Proxy> proxies,
}) {
  final ref = globalState.container;
  final columns = ref.read(proxiesColumnsProvider);
  final proxyCardType = ref.read(
    proxiesStyleSettingProvider.select((state) => state.cardType),
  );
  final selectedProxyName = ref.read(selectedProxyNameProvider(groupName));
  final findSelectedIndex = proxies.indexWhere(
    (proxy) => proxy.name == selectedProxyName,
  );
  final selectedIndex = findSelectedIndex != -1 ? findSelectedIndex : 0;
  final rows = (selectedIndex / columns).floor();
  return rows * getItemHeight(proxyCardType) + (rows - 1) * 8;
}
