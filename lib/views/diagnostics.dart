import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaml/yaml.dart';

// ── Models ──────────────────────────────────────────────────────────────────

enum DiagStatus { pending, running, pass, fail, skip }

class DiagStep {
  /// Stable identity for matching (dns/tcp/tls/http) — independent of the
  /// localized [title], so step lookup keeps working in every language.
  final String kind;
  final String title;
  final DiagStatus status;
  final String? detail;

  /// Measured latency for this step, when applicable (TCP connect / HTTP delay).
  final int? ms;

  const DiagStep(this.kind, this.title,
      {this.status = DiagStatus.pending, this.detail, this.ms});

  DiagStep copyWith({DiagStatus? status, String? detail, int? ms}) => DiagStep(
        kind,
        title,
        status: status ?? this.status,
        detail: detail ?? this.detail,
        ms: ms ?? this.ms,
      );
}

class NodeSpec {
  final String name;
  final String type;
  final String? server;
  final int? port;
  final bool usesTls;
  final String? sni;

  const NodeSpec({
    required this.name,
    required this.type,
    this.server,
    this.port,
    this.usesTls = false,
    this.sni,
  });
}

class NodeDiagnostic {
  final NodeSpec spec;
  final List<DiagStep> steps;
  final bool running;

  const NodeDiagnostic({
    required this.spec,
    required this.steps,
    this.running = false,
  });

  DiagStatus stepStatus(String kind) {
    for (final s in steps) {
      if (s.kind == kind) return s.status;
    }
    return DiagStatus.pending;
  }

  /// TCP handshake latency (host → node) — the "familiar" ping number.
  int? get tcpMs => _stepMs('tcp');

  /// Full HTTP(S) round-trip latency through the proxy.
  int? get httpMs => _stepMs('http');

  int? _stepMs(String kind) {
    for (final s in steps) {
      if (s.kind == kind && s.status == DiagStatus.pass) return s.ms;
    }
    return null;
  }

  /// Overall health status (no localization needed — drives colors/counts).
  DiagStatus get verdictStatus {
    if (running) return DiagStatus.running;
    if (steps.every((s) => s.status == DiagStatus.pending)) {
      return DiagStatus.pending;
    }
    if (stepStatus('dns') == DiagStatus.fail) return DiagStatus.fail;
    if (stepStatus('tcp') == DiagStatus.fail) return DiagStatus.fail;
    if (stepStatus('tls') == DiagStatus.fail) return DiagStatus.fail;
    if (stepStatus('http') == DiagStatus.fail) return DiagStatus.fail;
    if (stepStatus('http') == DiagStatus.pass) return DiagStatus.pass;
    return DiagStatus.skip;
  }

  /// Overall health, localized.
  String verdictText(AppLocalizations l) {
    if (running) return l.verdictTesting;
    if (steps.every((s) => s.status == DiagStatus.pending)) {
      return l.verdictNotTested;
    }
    if (stepStatus('dns') == DiagStatus.fail) return l.verdictDnsFailed;
    if (stepStatus('tcp') == DiagStatus.fail) return l.verdictServerNotResponding;
    if (stepStatus('tls') == DiagStatus.fail) return l.verdictTlsFailed;
    if (stepStatus('http') == DiagStatus.fail) return l.verdictCantPassTraffic;
    if (stepStatus('http') == DiagStatus.pass) return l.verdictHealthy;
    return l.verdictIncomplete;
  }

  /// A plain-language explanation + actionable fix for the first failing layer.
  ({String explanation, String fix}) advice(AppLocalizations l) {
    if (stepStatus('dns') == DiagStatus.fail) {
      return (explanation: l.adviceDnsExplanation, fix: l.adviceDnsFix);
    }
    if (stepStatus('tcp') == DiagStatus.fail) {
      return (explanation: l.adviceTcpExplanation, fix: l.adviceTcpFix);
    }
    if (stepStatus('tls') == DiagStatus.fail) {
      return (explanation: l.adviceTlsExplanation, fix: l.adviceTlsFix);
    }
    if (stepStatus('http') == DiagStatus.fail) {
      return (explanation: l.adviceHttpExplanation, fix: l.adviceHttpFix);
    }
    if (verdictStatus == DiagStatus.pass) {
      return (explanation: l.adviceHealthyExplanation, fix: l.adviceHealthyFix);
    }
    return (
      explanation: l.adviceIncompleteExplanation,
      fix: l.adviceIncompleteFix,
    );
  }
}

// ── Runner (pure Dart, no core changes) ─────────────────────────────────────

class DiagnosticRunner {
  static const _dnsTimeout = Duration(seconds: 5);
  static const _tcpTimeout = Duration(seconds: 5);
  static const _tlsTimeout = Duration(seconds: 6);

  static List<DiagStep> initialSteps(NodeSpec spec, AppLocalizations l) => [
        DiagStep('dns', l.stepDnsLookup),
        DiagStep('tcp', l.stepTcpConnectivity),
        if (spec.usesTls) DiagStep('tls', l.stepTlsHandshake),
        DiagStep('http', l.stepHttpDelay),
      ];

  static Future<List<DiagStep>> run(
    NodeSpec spec,
    AppLocalizations l,
    void Function(List<DiagStep>) onUpdate, {
    bool tcpOnly = false,
  }) async {
    final steps = initialSteps(spec, l).toList();
    int idx(String kind) => steps.indexWhere((s) => s.kind == kind);

    void set(int i, DiagStatus status, [String? detail, int? ms]) {
      if (i < 0) return;
      steps[i] = steps[i].copyWith(status: status, detail: detail, ms: ms);
      onUpdate(steps.toList());
    }

    final server = spec.server;
    final port = spec.port;

    // 1. DNS lookup
    set(idx('dns'), DiagStatus.running);
    if (server == null || server.isEmpty) {
      set(idx('dns'), DiagStatus.skip, l.detailNoServerAddress);
    } else if (InternetAddress.tryParse(server) != null) {
      set(idx('dns'), DiagStatus.skip, l.detailDirectIp(server));
    } else {
      try {
        final addrs = await InternetAddress.lookup(server).timeout(_dnsTimeout);
        if (addrs.isEmpty) {
          set(idx('dns'), DiagStatus.fail, l.detailNoAddressRecords(server));
        } else {
          set(idx('dns'), DiagStatus.pass,
              '$server → ${addrs.map((a) => a.address).take(3).join(', ')}');
        }
      } catch (e) {
        set(idx('dns'), DiagStatus.fail, _clean(e, l));
      }
    }

    // 2. TCP connectivity (host → node, bypassing the proxy)
    set(idx('tcp'), DiagStatus.running);
    if (server == null || server.isEmpty || port == null) {
      set(idx('tcp'), DiagStatus.skip, l.detailNoHostPort);
    } else {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(server, port, timeout: _tcpTimeout);
        sw.stop();
        socket.destroy();
        set(idx('tcp'), DiagStatus.pass,
            l.detailReachableMs(sw.elapsedMilliseconds), sw.elapsedMilliseconds);
      } catch (e) {
        sw.stop();
        set(idx('tcp'), DiagStatus.fail, _clean(e, l));
      }
    }

    // Fast TCP Ping mode stops here — skip the slower TLS/HTTP probes.
    if (tcpOnly) {
      final tlsIdx = idx('tls');
      if (tlsIdx >= 0) set(tlsIdx, DiagStatus.skip, l.detailSkippedFastPing);
      set(idx('http'), DiagStatus.skip, l.detailSkippedFastPing);
      return steps;
    }

    // 3. TLS / HTTPS handshake (only for TLS-bearing nodes)
    if (spec.usesTls) {
      set(idx('tls'), DiagStatus.running);
      if (server == null || server.isEmpty || port == null) {
        set(idx('tls'), DiagStatus.skip, l.detailNoHostPort);
      } else if (stepStatusOf(steps, 'tcp') == DiagStatus.fail) {
        set(idx('tls'), DiagStatus.skip, l.detailTlsSkippedNoTcp);
      } else {
        Socket? raw;
        try {
          raw = await Socket.connect(server, port, timeout: _tlsTimeout);
          final secure = await SecureSocket.secure(
            raw,
            host: spec.sni ?? server,
            onBadCertificate: (_) => true, // we only verify the handshake
          ).timeout(_tlsTimeout);
          final cn = _certName(secure.peerCertificate);
          await secure.close();
          set(idx('tls'), DiagStatus.pass,
              cn != null ? l.detailHandshakeOkCert(cn) : l.detailHandshakeOk);
        } catch (e) {
          raw?.destroy();
          set(idx('tls'), DiagStatus.fail, _clean(e, l));
        }
      }
    }

    // 4. HTTP delay through the proxy (reuses the core's URLTest)
    set(idx('http'), DiagStatus.running);
    try {
      final delay = await coreController.getDelay(defaultTestUrl, spec.name);
      final value = delay.value;
      if (value != null && value > 0) {
        set(idx('http'), DiagStatus.pass, l.detailMsViaProxy(value), value);
      } else {
        // The core reports mihomo's real reason (reality/TLS/timeout/reset)
        // when available, otherwise a localized fallback.
        final reason = delay.message;
        set(idx('http'), DiagStatus.fail,
            reason != null && reason.isNotEmpty
                ? reason
                : l.detailNoResponseProxy);
      }
    } catch (e) {
      set(idx('http'), DiagStatus.fail, _clean(e, l));
    }

    return steps;
  }

  static DiagStatus stepStatusOf(List<DiagStep> steps, String kind) {
    for (final s in steps) {
      if (s.kind == kind) return s.status;
    }
    return DiagStatus.pending;
  }

  static String? _certName(X509Certificate? cert) {
    if (cert == null) return null;
    final subject = cert.subject;
    final match = RegExp(r'CN=([^,/\n]+)').firstMatch(subject);
    return match?.group(1)?.trim() ?? (subject.isNotEmpty ? subject : null);
  }

  static String _clean(Object e, AppLocalizations l) {
    var s = e.toString();
    if (s.startsWith('SocketException: ')) s = s.substring(17);
    if (s.startsWith('HandshakeException: ')) s = s.substring(20);
    if (s.startsWith('TlsException: ')) s = s.substring(14);
    if (s.contains('TimeoutException')) s = l.timedOut;
    final paren = s.indexOf(' (');
    if (paren > 0) s = s.substring(0, paren);
    return s.trim();
  }
}

// ── Page ────────────────────────────────────────────────────────────────────

class DiagnosticsView extends ConsumerStatefulWidget {
  const DiagnosticsView({super.key});

  @override
  ConsumerState<DiagnosticsView> createState() => _DiagnosticsViewState();
}

class _DiagnosticsViewState extends ConsumerState<DiagnosticsView> {
  final Map<String, NodeDiagnostic> _results = {};
  List<NodeSpec> _nodes = [];
  String? _profileLabel;
  bool _loading = true;
  bool _runningAll = false;
  String? _error;

  IpInfo? _exitIp;
  bool _exitIpChecking = false;
  bool _exitIpDone = false;

  @override
  void initState() {
    super.initState();
    _loadNodes();
    _checkExitIp();
  }

  /// Real-connection check: what IP/country the internet actually sees through
  /// the current connection (reuses the app's existing checkIp, which routes
  /// via the selected node when connected).
  Future<void> _checkExitIp() async {
    setState(() {
      _exitIpChecking = true;
      _exitIpDone = false;
    });
    final res = await request.checkIp();
    if (!mounted) return;
    setState(() {
      _exitIp = res.data;
      _exitIpChecking = false;
      _exitIpDone = true;
    });
  }

  Future<void> _loadNodes() async {
    try {
      final profile = ref.read(currentProfileProvider);
      if (profile == null) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.current.noActiveProfileImport;
        });
        return;
      }
      _profileLabel = profile.label.isNotEmpty ? profile.label : profile.url;
      final path = await appPath.getProfilePath('${profile.id}');
      final file = File(path);
      if (!await file.exists()) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.current.profileFileNotFound;
        });
        return;
      }
      final doc = loadYaml(await file.readAsString());
      final proxies = (doc is YamlMap) ? doc['proxies'] : null;
      final specs = <NodeSpec>[];
      if (proxies is YamlList) {
        for (final p in proxies) {
          if (p is! YamlMap) continue;
          final name = p['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          final portRaw = p['port'];
          final tls = p['tls'] == true || p['security']?.toString() == 'tls';
          final type = p['type']?.toString() ?? '';
          specs.add(NodeSpec(
            name: name,
            type: type,
            server: p['server']?.toString(),
            port: portRaw is int
                ? portRaw
                : int.tryParse(portRaw?.toString() ?? ''),
            usesTls: tls || type == 'trojan',
            sni: p['servername']?.toString() ?? p['sni']?.toString(),
          ));
        }
      }
      setState(() {
        _nodes = specs;
        _loading = false;
        for (final spec in specs) {
          _results[spec.name] = NodeDiagnostic(
            spec: spec,
            steps: DiagnosticRunner.initialSteps(spec, AppLocalizations.current),
          );
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.current.failedToReadNodes('$e');
      });
    }
  }

  Future<void> _runOne(NodeSpec spec, {bool tcpOnly = false}) async {
    final l = AppLocalizations.current;
    void put(List<DiagStep> steps, bool running) {
      if (!mounted) return;
      setState(() {
        _results[spec.name] =
            NodeDiagnostic(spec: spec, steps: steps, running: running);
      });
    }

    put(DiagnosticRunner.initialSteps(spec, l), true);
    final steps = await DiagnosticRunner.run(
      spec,
      l,
      (s) => put(s, true),
      tcpOnly: tcpOnly,
    );
    put(steps, false);
  }

  Future<void> _runAll({bool tcpOnly = false}) async {
    if (_runningAll) return;
    setState(() => _runningAll = true);
    // Fast ping is cheap (host→node TCP only), so it can fan out wider.
    final batchSize = tcpOnly ? 16 : 4;
    for (var i = 0; i < _nodes.length; i += batchSize) {
      await Future.wait(
        _nodes.skip(i).take(batchSize).map((s) => _runOne(s, tcpOnly: tcpOnly)),
      );
      if (!mounted) return;
    }
    if (mounted) setState(() => _runningAll = false);
  }

  void _copyReport() {
    // The clipboard report is intentionally kept in English so it's portable
    // for support, but the per-node verdicts/advice use the active language.
    final l = AppLocalizations.current;
    final b = StringBuffer();
    b.writeln('LongyunVPN Diagnostic Report');
    b.writeln('Generated: ${DateTime.now().toString().split('.').first}');
    if (_profileLabel != null) b.writeln('Profile: $_profileLabel');
    b.writeln('Nodes: ${_nodes.length}  ·  Test URL: $defaultTestUrl');
    final healthy = _results.values
        .where((d) => d.verdictStatus == DiagStatus.pass)
        .length;
    final failing = _results.values
        .where((d) => d.verdictStatus == DiagStatus.fail)
        .length;
    b.writeln('Summary: $healthy healthy, $failing failing, '
        '${_nodes.length - healthy - failing} other');
    b.writeln('=' * 40);
    for (final spec in _nodes) {
      final d = _results[spec.name]!;
      b.writeln();
      b.writeln('[${spec.name}]  ${spec.type}'
          '${spec.server != null ? '  ${spec.server}:${spec.port ?? '?'}' : ''}');
      b.writeln('  Health: ${d.verdictText(l)}');
      for (final s in d.steps) {
        b.writeln('  - ${s.title}: ${s.status.name}'
            '${s.detail != null ? ' — ${s.detail}' : ''}');
      }
      if (d.verdictStatus == DiagStatus.fail) {
        final advice = d.advice(l);
        b.writeln('  Why: ${advice.explanation}');
        b.writeln('  Fix: ${advice.fix}');
      }
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    globalState.showNotifier(l.reportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return CommonScaffold(
      title: l.diagnostics,
      actions: [
        IconButton(
          tooltip: l.copyReport,
          onPressed: _nodes.isEmpty ? null : _copyReport,
          icon: const Icon(Icons.copy_all),
        ),
        if (_runningAll)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else ...[
          IconButton(
            tooltip: l.fastTcpPing,
            onPressed: _nodes.isEmpty ? null : () => _runAll(tcpOnly: true),
            icon: const Icon(Icons.speed),
          ),
          IconButton(
            tooltip: l.runFullTests,
            onPressed: _nodes.isEmpty ? null : () => _runAll(),
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_nodes.isEmpty) {
      return Center(child: Text(context.appLocalizations.noNodesFound));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _nodes.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _ExitIpBanner(
            ipInfo: _exitIp,
            checking: _exitIpChecking,
            done: _exitIpDone,
            onRefresh: _checkExitIp,
          );
        }
        if (i == 1) return _SummaryBanner(results: _results.values.toList());
        final diag = _results[_nodes[i - 2].name]!;
        return _NodeCard(diagnostic: diag, onRun: () => _runOne(diag.spec));
      },
    );
  }
}

class _ExitIpBanner extends StatelessWidget {
  final IpInfo? ipInfo;
  final bool checking;
  final bool done;
  final VoidCallback onRefresh;

  const _ExitIpBanner({
    required this.ipInfo,
    required this.checking,
    required this.done,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final ok = ipInfo != null;
    final color = checking
        ? theme.colorScheme.onSurfaceVariant
        : (ok ? Colors.green : theme.colorScheme.error);
    final String text;
    if (checking) {
      text = l.exitIpChecking;
    } else if (ok) {
      final cc = ipInfo!.countryCode;
      text = l.exitIpValue('${ipInfo!.ip}${cc.isNotEmpty ? '  ·  $cc' : ''}');
    } else if (done) {
      text = l.exitIpUnavailable;
    } else {
      text = l.exitIpValue('—');
    }
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(ok ? Icons.public : Icons.public_off, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: l.recheckExitIp,
              onPressed: checking ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final List<NodeDiagnostic> results;

  const _SummaryBanner({required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final healthy =
        results.where((d) => d.verdictStatus == DiagStatus.pass).length;
    final failing =
        results.where((d) => d.verdictStatus == DiagStatus.fail).length;
    final tested = healthy + failing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          _chip(context, Icons.check_circle, Colors.green, l.nHealthy(healthy)),
          const SizedBox(width: 8),
          _chip(context, Icons.cancel, theme.colorScheme.error,
              l.nFailing(failing)),
          const SizedBox(width: 8),
          _chip(context, Icons.dns, theme.colorScheme.onSurfaceVariant,
              l.nTotal(results.length)),
          const Spacer(),
          if (tested == 0)
            Text(l.tapToTest,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final int ms;
  final Color color;

  const _MetricChip({required this.label, required this.ms, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $ms ms',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final NodeDiagnostic diagnostic;
  final VoidCallback onRun;

  const _NodeCard({required this.diagnostic, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final verdictStatus = diagnostic.verdictStatus;
    final verdictText = diagnostic.verdictText(l);
    final isFail = verdictStatus == DiagStatus.fail;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: _statusIcon(context, verdictStatus),
          title: Text(
            diagnostic.spec.name,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  verdictText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: _color(context, verdictStatus)),
                ),
              ),
              if (diagnostic.tcpMs != null) ...[
                const SizedBox(width: 8),
                _MetricChip(
                    label: 'TCP', ms: diagnostic.tcpMs!, color: Colors.blue),
              ],
              if (diagnostic.httpMs != null) ...[
                const SizedBox(width: 6),
                _MetricChip(
                    label: 'HTTP',
                    ms: diagnostic.httpMs!,
                    color: theme.colorScheme.primary),
              ],
            ],
          ),
          trailing: IconButton(
            tooltip: l.runTest,
            onPressed: diagnostic.running ? null : onRun,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${diagnostic.spec.type}'
                    '${diagnostic.spec.server != null ? ' · ${diagnostic.spec.server}:${diagnostic.spec.port ?? '?'}' : ''}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  for (final step in diagnostic.steps)
                    _StepRow(step: step),
                  if (isFail) ...[
                    const SizedBox(height: 12),
                    _adviceBox(context, diagnostic.advice(l)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adviceBox(
      BuildContext context, ({String explanation, String fix}) advice) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(advice.explanation, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.fix,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _color(BuildContext context, DiagStatus status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      DiagStatus.pass => Colors.green,
      DiagStatus.fail => cs.error,
      _ => cs.onSurfaceVariant,
    };
  }

  Widget _statusIcon(BuildContext context, DiagStatus status,
      {double size = 22}) {
    switch (status) {
      case DiagStatus.running:
        return SizedBox(
          width: size,
          height: size,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case DiagStatus.pass:
        return Icon(Icons.check_circle, color: Colors.green, size: size);
      case DiagStatus.fail:
        return Icon(Icons.cancel,
            color: Theme.of(context).colorScheme.error, size: size);
      case DiagStatus.skip:
        return Icon(Icons.remove_circle_outline,
            color: Theme.of(context).colorScheme.onSurfaceVariant, size: size);
      case DiagStatus.pending:
        return Icon(Icons.radio_button_unchecked,
            color: Theme.of(context).colorScheme.outlineVariant, size: size);
    }
  }
}

class _StepRow extends StatelessWidget {
  final DiagStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (step.status) {
      DiagStatus.pass => Colors.green,
      DiagStatus.fail => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (step.status) {
      DiagStatus.pass => Icons.check_circle,
      DiagStatus.fail => Icons.cancel,
      DiagStatus.skip => Icons.remove_circle_outline,
      DiagStatus.running => Icons.timelapse,
      DiagStatus.pending => Icons.radio_button_unchecked,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step.status == DiagStatus.running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: theme.textTheme.bodyMedium),
                if (step.detail != null)
                  Text(step.detail!,
                      style: theme.textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
