import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common.dart';

/// Built-in pseudo proxies that are never real server nodes.
const _builtInProxies = {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
  'GLOBAL',
};

/// Collects the unique, real server nodes across all proxy groups. Group
/// references (sub-groups such as Auto Select / Fallback) and the built-in
/// pseudo proxies are excluded so the list only contains actual outbound nodes.
List<Proxy> collectNodes(List<Group> groups) {
  final groupNames = groups.map((g) => g.name).toSet();
  final seen = <String>{};
  final nodes = <Proxy>[];
  for (final group in groups) {
    for (final proxy in group.all) {
      final name = proxy.name;
      if (seen.contains(name)) continue;
      if (groupNames.contains(name)) continue;
      if (_builtInProxies.contains(name.toUpperCase())) continue;
      seen.add(name);
      nodes.add(proxy);
    }
  }
  return nodes;
}

/// Parses a leading 2-letter ISO country code from a node name, e.g.
/// "HK 香港L01 | x1.5" -> "HK". Returns null when none is found.
String? _countryCode(String name) {
  final match = RegExp(r'\b([A-Za-z]{2})\b').firstMatch(name);
  return match?.group(1)?.toUpperCase();
}

/// Converts an ISO country code to its flag emoji (regional indicators).
String _flagEmoji(String code) {
  if (code.length != 2) return '';
  const base = 0x1F1E6; // regional indicator 'A'
  final cu = code.toUpperCase().codeUnits;
  return String.fromCharCodes([base + (cu[0] - 65), base + (cu[1] - 65)]);
}

/// Parses a traffic multiplier such as "x1.5" from a node name.
String? _multiplier(String name) {
  final match = RegExp(r'[xX](\d+(?:\.\d+)?)').firstMatch(name);
  return match == null ? null : 'x${match.group(1)}';
}

/// Empty-state shown on the Servers page when the account has no active
/// subscription. Offers a shortcut to buy a plan and a refresh that re-checks
/// the subscription from the panel.
class NoSubscriptionView extends ConsumerStatefulWidget {
  const NoSubscriptionView({super.key});

  @override
  ConsumerState<NoSubscriptionView> createState() => _NoSubscriptionViewState();
}

class _NoSubscriptionViewState extends ConsumerState<NoSubscriptionView> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(authProvider.notifier).refresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.noActiveSubscription,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.noSubscriptionServersMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(currentPageLabelProvider.notifier)
                      .toPage(PageLabel.premium),
                  icon: const Icon(Icons.bolt),
                  label: Text(l.buyPremium),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l.refresh),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Node Status" tab: a responsive health dashboard for every server node,
/// with total/online/offline counters and a health-only refresh that re-tests
/// latency without re-downloading the subscription.
class NodeStatusView extends ConsumerStatefulWidget {
  const NodeStatusView({super.key});

  @override
  ConsumerState<NodeStatusView> createState() => _NodeStatusViewState();
}

class _NodeStatusViewState extends ConsumerState<NodeStatusView> {
  bool _refreshing = false;

  Future<void> _refreshStatus(List<Proxy> nodes, String? testUrl) async {
    if (_refreshing || nodes.isEmpty) return;
    setState(() => _refreshing = true);
    try {
      await delayTest(nodes, testUrl);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final groups = ref.watch(
      proxiesTabStateProvider.select((state) => state.groups),
    );
    final nodes = collectNodes(groups);
    final testUrl = groups.isNotEmpty ? groups.first.testUrl : null;

    var online = 0;
    var offline = 0;
    for (final node in nodes) {
      final d = ref.watch(
        delayProvider(proxyName: node.name, testUrl: testUrl),
      );
      if (d != null && d > 0) {
        online++;
      } else if (d != null && d < 0) {
        offline++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: l.totalNodes,
                      value: '${nodes.length}',
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.dns_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: l.onlineNodes,
                      value: '$online',
                      color: const Color(0xFF43A047),
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: l.offlineNodes,
                      value: '$offline',
                      color: const Color(0xFFE53935),
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _refreshing ? null : () => _refreshStatus(nodes, testUrl),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l.refreshStatus),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Text(
                    l.nullTip(l.proxies),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    mainAxisExtent: 116,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: nodes.length,
                  itemBuilder: (_, index) => _NodeCard(
                    proxy: nodes[index],
                    testUrl: testUrl,
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCard extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;

  const _NodeCard({required this.proxy, required this.testUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: testUrl),
    );
    final online = delay != null && delay > 0;
    final testing = delay == 0;
    final offline = delay != null && delay < 0;

    final (Color statusColor, String statusText) = switch (true) {
      _ when online => (const Color(0xFF43A047), context.appLocalizations.online),
      _ when offline =>
        (const Color(0xFFE53935), context.appLocalizations.offline),
      _ => (theme.colorScheme.outline, '—'),
    };

    final code = _countryCode(proxy.name);
    final multiplier = _multiplier(proxy.name);

    return CommonCard(
      onPressed: () => proxyDelayTest(proxy, testUrl),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (code != null) ...[
                  _CountryChip(code: code),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Icon(Icons.circle, size: 9, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            EmojiText(
              proxy.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Flexible(
                  child: Text(
                    proxy.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (multiplier != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: theme.colorScheme.secondaryContainer,
                    ),
                    child: Text(
                      multiplier,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (testing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    online ? '$delay ms' : (offline ? statusText : '—'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: online ? utils.getDelayColor(delay) : statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  final String code;

  const _CountryChip({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = _flagEmoji(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: EmojiText(
        flag.isEmpty ? code : '$flag $code',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
