import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

/// Built-in pseudo proxies that are never real server nodes.
const _builtInProxies = {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
  'GLOBAL',
};

/// Collects the unique, selectable server nodes across all proxy groups. Group
/// references (sub-groups such as Auto Select / Fallback) and the built-in
/// pseudo proxies are excluded so the list only contains real outbound nodes.
/// Used by the Servers-page subscription gate to decide whether usable nodes
/// exist.
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

// ── No-subscription / no-nodes empty state ───────────────────────────────────

/// Empty-state shown on the Servers page when the account has no active
/// subscription ([noNodes] = false) or has a subscription but no usable nodes
/// ([noNodes] = true). Offers a shortcut to buy a plan and a refresh: re-check
/// the account, or (for no-nodes) re-download the subscription.
class NoSubscriptionView extends ConsumerStatefulWidget {
  final bool noNodes;

  const NoSubscriptionView({super.key, this.noNodes = false});

  @override
  ConsumerState<NoSubscriptionView> createState() => _NoSubscriptionViewState();
}

class _NoSubscriptionViewState extends ConsumerState<NoSubscriptionView> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      if (widget.noNodes) {
        // Re-download the active subscription so freshly-purchased nodes appear.
        final profile = ref.read(currentProfileProvider);
        if (profile != null) {
          await ref
              .read(profilesActionProvider.notifier)
              .updateProfile(profile, showLoading: true);
        }
      }
      await ref.read(authProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final theme = Theme.of(context);
    final title = widget.noNodes ? l.noNodesAvailable : l.noActiveSubscription;
    final message =
        widget.noNodes ? l.refreshSubscriptionHint : l.noSubscriptionServersMessage;
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
                  widget.noNodes
                      ? Icons.cloud_off_outlined
                      : Icons.workspace_premium_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
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

/// Centered "No nodes found / please refresh" hint shown inside a proxy group
/// (or the whole tab area) when a group has no proxies.
class NoNodesHint extends StatelessWidget {
  const NoNodesHint({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              l.noNodesFoundTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l.refreshSubscriptionHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Node health model + checker ──────────────────────────────────────────────

/// One server node parsed from the active profile, plus its last health result.
class _NodeInfo {
  final String name;
  final String type;
  final String? server;
  final int? port;

  bool? tcpOk; // null = not checked yet
  bool? httpOk;
  int? latencyMs; // HTTP round-trip through the proxy
  int? tcpMs;
  DateTime? checkedAt;
  bool checking = false;

  _NodeInfo({
    required this.name,
    required this.type,
    this.server,
    this.port,
    this.tcpOk,
    this.httpOk,
    this.latencyMs,
    this.tcpMs,
    this.checkedAt,
  });

  /// Online  = TCP OK + HTTP OK.
  /// Offline = TCP failed.
  /// Unknown = TCP OK but HTTP failed/timeout, or not yet checked.
  /// A timeout is never reported as Offline.
  NodeHealthStatus get status {
    if (tcpOk == false) return NodeHealthStatus.offline;
    if (tcpOk == true && httpOk == true) return NodeHealthStatus.online;
    // No TCP target (server/port unknown) — fall back to the HTTP result.
    if (tcpOk == null && httpOk == true) return NodeHealthStatus.online;
    if (tcpOk == null && httpOk == null && checkedAt == null) {
      return NodeHealthStatus.unknown;
    }
    return NodeHealthStatus.unknown;
  }
}

enum NodeHealthStatus { online, offline, unknown }

class _HealthRunner {
  static const _tcpTimeout = Duration(seconds: 5);

  /// Runs a TCP connect (host → node, bypassing the proxy) and an HTTP delay
  /// test (through the proxy) for a single node, mutating it in place.
  static Future<void> check(_NodeInfo node) async {
    // 1. TCP connectivity to the node's server:port.
    if (node.server != null && node.server!.isNotEmpty && node.port != null) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          node.server!,
          node.port!,
          timeout: _tcpTimeout,
        );
        sw.stop();
        socket.destroy();
        node.tcpOk = true;
        node.tcpMs = sw.elapsedMilliseconds;
      } catch (_) {
        node.tcpOk = false;
        node.tcpMs = null;
      }
    } else {
      node.tcpOk = null;
    }

    // 2. HTTP delay through the proxy (reuses the core's URLTest).
    try {
      final delay = await coreController.getDelay(defaultTestUrl, node.name);
      final value = delay.value;
      if (value != null && value > 0) {
        node.httpOk = true;
        node.latencyMs = value;
      } else {
        node.httpOk = false;
        node.latencyMs = null;
      }
    } catch (_) {
      node.httpOk = false;
      node.latencyMs = null;
    }

    node.checkedAt = DateTime.now();
  }
}

// ── Node Status tab ──────────────────────────────────────────────────────────

class NodeStatusView extends ConsumerStatefulWidget {
  const NodeStatusView({super.key});

  @override
  ConsumerState<NodeStatusView> createState() => _NodeStatusViewState();
}

class _NodeStatusViewState extends ConsumerState<NodeStatusView> {
  List<_NodeInfo> _nodes = [];
  bool _loading = true;
  int? _loadedProfileId;

  bool _refreshing = false;
  bool _justCompleted = false;
  int _checked = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  /// Parses the server nodes (name/type/server/port) from the active profile's
  /// downloaded config. This does not re-download anything.
  Future<void> _loadNodes() async {
    final profile = ref.read(currentProfileProvider);
    _loadedProfileId = profile?.id;
    if (profile == null) {
      setState(() {
        _nodes = [];
        _loading = false;
      });
      return;
    }
    try {
      final path = await appPath.getProfilePath('${profile.id}');
      final file = File(path);
      if (!await file.exists()) {
        setState(() {
          _nodes = [];
          _loading = false;
        });
        return;
      }
      final doc = loadYaml(await file.readAsString());
      final proxies = (doc is YamlMap) ? doc['proxies'] : null;
      final previous = {for (final n in _nodes) n.name: n};
      final nodes = <_NodeInfo>[];
      if (proxies is YamlList) {
        for (final p in proxies) {
          if (p is! YamlMap) continue;
          final name = p['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          final portRaw = p['port'];
          // Carry over the last health result so a reload doesn't wipe status.
          final prev = previous[name];
          nodes.add(_NodeInfo(
            name: name,
            type: p['type']?.toString() ?? '',
            server: p['server']?.toString(),
            port: portRaw is int
                ? portRaw
                : int.tryParse(portRaw?.toString() ?? ''),
            tcpOk: prev?.tcpOk,
            httpOk: prev?.httpOk,
            latencyMs: prev?.latencyMs,
            tcpMs: prev?.tcpMs,
            checkedAt: prev?.checkedAt,
          ));
        }
      }
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nodes = [];
        _loading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    if (_refreshing || _nodes.isEmpty) return;
    setState(() {
      _refreshing = true;
      _justCompleted = false;
      _checked = 0;
    });
    const batch = 8;
    for (var i = 0; i < _nodes.length; i += batch) {
      await Future.wait(_nodes.skip(i).take(batch).map((node) async {
        await _HealthRunner.check(node);
        if (mounted) setState(() => _checked++);
      }));
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _justCompleted = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _justCompleted = false);
    });
  }

  Future<void> _recheckOne(_NodeInfo node) async {
    if (node.checking) return;
    setState(() => node.checking = true);
    await _HealthRunner.check(node);
    if (mounted) setState(() => node.checking = false);
  }

  List<_NodeInfo> get _visibleNodes {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _nodes.toList()
        : _nodes
            .where((n) =>
                n.name.toLowerCase().contains(q) ||
                (_countryCode(n.name)?.toLowerCase().contains(q) ?? false))
            .toList();
    // Sort alphabetically by country code, then by node name.
    filtered.sort((a, b) {
      final ca = _countryCode(a.name) ?? 'ZZ';
      final cb = _countryCode(b.name) ?? 'ZZ';
      final byCountry = ca.compareTo(cb);
      return byCountry != 0 ? byCountry : a.name.compareTo(b.name);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;

    // Reload node specs when the active profile changes (e.g. after a refresh).
    ref.listen(currentProfileProvider.select((p) => p?.id), (prev, next) {
      if (next != _loadedProfileId) _loadNodes();
    });

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nodes.isEmpty) {
      return const NoNodesHint();
    }

    final online =
        _nodes.where((n) => n.status == NodeHealthStatus.online).length;
    final offline =
        _nodes.where((n) => n.status == NodeHealthStatus.offline).length;
    final unknown =
        _nodes.where((n) => n.status == NodeHealthStatus.unknown).length;
    final lastUpdated = _nodes
        .map((n) => n.checkedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    final visible = _visibleNodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SummaryCard(
            total: _nodes.length,
            online: online,
            offline: offline,
            unknown: unknown,
            lastUpdated: lastUpdated,
            refreshing: _refreshing,
            justCompleted: _justCompleted,
            checked: _checked,
            onRefresh: _refreshStatus,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: l.search,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    l.noNodesFoundTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 162,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (_, index) => _NodeCard(
                    node: visible[index],
                    onTap: () => _recheckOne(visible[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int online;
  final int offline;
  final int unknown;
  final DateTime? lastUpdated;
  final bool refreshing;
  final bool justCompleted;
  final int checked;
  final VoidCallback onRefresh;

  const _SummaryCard({
    required this.total,
    required this.online,
    required this.offline,
    required this.unknown,
    required this.lastUpdated,
    required this.refreshing,
    required this.justCompleted,
    required this.checked,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;

    final String refreshLabel;
    if (refreshing) {
      refreshLabel =
          checked == 0 ? l.refreshing : l.checkingProgress(checked, total);
    } else if (justCompleted) {
      refreshLabel = l.completed;
    } else {
      refreshLabel = l.refreshStatus;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l.totalNodes,
                  value: '$total',
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l.onlineNodes,
                  value: '$online',
                  color: const Color(0xFF43A047),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l.offlineNodes,
                  value: '$offline',
                  color: const Color(0xFFE53935),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l.unknownNodes,
                  value: '$unknown',
                  color: const Color(0xFFFB8C00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '${l.lastUpdated}: ${lastUpdated == null ? l.never : DateFormat.Hms().format(lastUpdated!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(refreshLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
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
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  final _NodeInfo node;
  final VoidCallback onTap;

  const _NodeCard({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final status = node.status;
    final (Color statusColor, String statusText) = switch (status) {
      NodeHealthStatus.online => (const Color(0xFF43A047), l.online),
      NodeHealthStatus.offline => (const Color(0xFFE53935), l.offline),
      NodeHealthStatus.unknown => (const Color(0xFFFB8C00), l.unknown),
    };
    final code = _countryCode(node.name);
    final multiplier = _multiplier(node.name);

    return CommonCard(
      onPressed: onTap,
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
                if (node.checking)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Icon(Icons.circle, size: 9, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            EmojiText(
              node.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Flexible(
                  child: Text(
                    node.type,
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
                Text(
                  node.latencyMs != null ? '${node.latencyMs} ms' : '—',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: node.latencyMs != null
                        ? utils.getDelayColor(node.latencyMs)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                _CheckChip(label: 'TCP', ok: node.tcpOk),
                const SizedBox(width: 6),
                _CheckChip(label: 'HTTP', ok: node.httpOk),
                const Spacer(),
                Text(
                  node.checkedAt == null
                      ? '${l.lastChecked}: ${l.never}'
                      : '${l.lastChecked}: ${DateFormat.Hm().format(node.checkedAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _CheckChip extends StatelessWidget {
  final String label;
  final bool? ok; // null = not checked

  const _CheckChip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (ok) {
      true => const Color(0xFF43A047),
      false => const Color(0xFFE53935),
      null => theme.colorScheme.outline,
    };
    final icon = switch (ok) {
      true => Icons.check,
      false => Icons.close,
      null => Icons.remove,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          Icon(icon, size: 12, color: color),
        ],
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
