import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Localization ─────────────────────────────────────────────────────────────
//
// This feature's strings live here rather than in the generated Flutter-Intl
// bundle (arb/ + lib/l10n/) so the view can be added without a code-generation
// pass. Keyed by language code; falls back to English. When the l10n bundle is
// next regenerated these can be migrated into it.

class _Strings {
  final String title;
  final String menuDesc;
  final String intro;
  final String run;
  final String running;
  final String notConnected;
  final String verdictProtected;
  final String verdictLeak;
  final String verdictWarn;
  final String verdictError;
  final String rowExitIp;
  final String rowRealIp;
  final String rowIpv6;
  final String sameAsReal;
  final String differsFromReal;
  final String ipv6None;
  final String ipv6Exposed;
  final String couldNotDetermine;
  final String footnote;

  const _Strings({
    required this.title,
    required this.menuDesc,
    required this.intro,
    required this.run,
    required this.running,
    required this.notConnected,
    required this.verdictProtected,
    required this.verdictLeak,
    required this.verdictWarn,
    required this.verdictError,
    required this.rowExitIp,
    required this.rowRealIp,
    required this.rowIpv6,
    required this.sameAsReal,
    required this.differsFromReal,
    required this.ipv6None,
    required this.ipv6Exposed,
    required this.couldNotDetermine,
    required this.footnote,
  });
}

const _en = _Strings(
  title: 'Leak test',
  menuDesc: 'Check whether your traffic is really tunneled',
  intro:
      'Checks whether your traffic is really going through the VPN by comparing '
      'your exit IP with your real IP, and whether an IPv6 address is exposed.',
  run: 'Run test',
  running: 'Testing…',
  notConnected: 'The VPN is not connected. Connect first, then run the test.',
  verdictProtected: 'Protected — your real IP is hidden',
  verdictLeak: 'Leak detected — your traffic is not going through the VPN',
  verdictWarn: 'Possible leak — review the details below',
  verdictError: 'Could not complete the test (network error)',
  rowExitIp: 'Exit IP (through VPN)',
  rowRealIp: 'Your real IP (direct)',
  rowIpv6: 'IPv6 exposure',
  sameAsReal: 'Same as your real IP',
  differsFromReal: 'Different from your real IP',
  ipv6None: 'No public IPv6 exposed',
  ipv6Exposed: 'Public IPv6 reachable — may bypass the tunnel',
  couldNotDetermine: 'Could not determine',
  footnote:
      'This checks IPv4, IPv6 and exit-IP masking. It cannot detect every '
      'possible leak type (for example DNS).',
);

const _zh = _Strings(
  title: '泄漏检测',
  menuDesc: '检查流量是否真正通过隧道',
  intro: '通过比较你的出口 IP 与真实 IP 来检查流量是否真正经过 VPN，并检测是否暴露了 IPv6 地址。',
  run: '开始检测',
  running: '检测中…',
  notConnected: 'VPN 尚未连接。请先连接，然后再运行检测。',
  verdictProtected: '已保护 —— 你的真实 IP 已被隐藏',
  verdictLeak: '检测到泄漏 —— 你的流量没有经过 VPN',
  verdictWarn: '可能存在泄漏 —— 请查看下方详情',
  verdictError: '无法完成检测（网络错误）',
  rowExitIp: '出口 IP（经 VPN）',
  rowRealIp: '你的真实 IP（直连）',
  rowIpv6: 'IPv6 暴露',
  sameAsReal: '与真实 IP 相同',
  differsFromReal: '与真实 IP 不同',
  ipv6None: '未暴露公网 IPv6',
  ipv6Exposed: '可访问公网 IPv6 —— 可能绕过隧道',
  couldNotDetermine: '无法确定',
  footnote: '此检测涵盖 IPv4、IPv6 与出口 IP 遮蔽，无法检测所有类型的泄漏（例如 DNS）。',
);

const _ja = _Strings(
  title: 'リークテスト',
  menuDesc: '通信が本当にトンネルを経由しているか確認',
  intro: '出口 IP と実際の IP を比較して通信が本当に VPN を経由しているかを確認し、IPv6 アドレスが露出していないかを検査します。',
  run: 'テストを実行',
  running: 'テスト中…',
  notConnected: 'VPN が接続されていません。先に接続してからテストを実行してください。',
  verdictProtected: '保護されています —— 実際の IP は隠されています',
  verdictLeak: 'リークを検出 —— 通信が VPN を経由していません',
  verdictWarn: 'リークの可能性 —— 下の詳細を確認してください',
  verdictError: 'テストを完了できませんでした（ネットワークエラー）',
  rowExitIp: '出口 IP（VPN 経由）',
  rowRealIp: '実際の IP（直接）',
  rowIpv6: 'IPv6 の露出',
  sameAsReal: '実際の IP と同じ',
  differsFromReal: '実際の IP と異なる',
  ipv6None: '公開 IPv6 の露出なし',
  ipv6Exposed: '公開 IPv6 に到達可能 —— トンネルを迂回する可能性',
  couldNotDetermine: '判定できません',
  footnote: 'このテストは IPv4・IPv6・出口 IP のマスキングを確認します。すべての種類のリーク（例：DNS）を検出できるわけではありません。',
);

const _ru = _Strings(
  title: 'Тест на утечки',
  menuDesc: 'Проверить, действительно ли трафик идёт через туннель',
  intro:
      'Проверяет, действительно ли трафик идёт через VPN, сравнивая выходной IP '
      'с вашим реальным IP, а также не раскрыт ли адрес IPv6.',
  run: 'Запустить тест',
  running: 'Проверка…',
  notConnected: 'VPN не подключён. Сначала подключитесь, затем запустите тест.',
  verdictProtected: 'Защищено — ваш реальный IP скрыт',
  verdictLeak: 'Обнаружена утечка — трафик не идёт через VPN',
  verdictWarn: 'Возможна утечка — проверьте детали ниже',
  verdictError: 'Не удалось завершить тест (ошибка сети)',
  rowExitIp: 'Выходной IP (через VPN)',
  rowRealIp: 'Ваш реальный IP (напрямую)',
  rowIpv6: 'Раскрытие IPv6',
  sameAsReal: 'Совпадает с вашим реальным IP',
  differsFromReal: 'Отличается от вашего реального IP',
  ipv6None: 'Публичный IPv6 не раскрыт',
  ipv6Exposed: 'Доступен публичный IPv6 — может обходить туннель',
  couldNotDetermine: 'Не удалось определить',
  footnote:
      'Тест проверяет IPv4, IPv6 и маскировку выходного IP. Он не выявляет все '
      'возможные типы утечек (например, DNS).',
);

_Strings _stringsFor(BuildContext context) {
  switch (Localizations.localeOf(context).languageCode) {
    case 'zh':
      return _zh;
    case 'ja':
      return _ja;
    case 'ru':
      return _ru;
    default:
      return _en;
  }
}

/// Localized label/subtitle for the Tools menu entry (public so tools.dart can
/// build the list item without touching the private strings table).
String leakTestTitle(BuildContext context) => _stringsFor(context).title;

String leakTestMenuDesc(BuildContext context) => _stringsFor(context).menuDesc;

// ── Model ────────────────────────────────────────────────────────────────────

enum _CheckState { pending, running, pass, warn, fail }

enum _Verdict { none, protected, leak, warn, error, notConnected }

class _CheckRow {
  final String title;
  final _CheckState state;
  final String? value;
  final String? detail;

  const _CheckRow(
    this.title, {
    this.state = _CheckState.pending,
    this.value,
    this.detail,
  });
}

// ── View ─────────────────────────────────────────────────────────────────────

class LeakTestView extends ConsumerStatefulWidget {
  const LeakTestView({super.key});

  @override
  ConsumerState<LeakTestView> createState() => _LeakTestViewState();
}

class _LeakTestViewState extends ConsumerState<LeakTestView> {
  bool _running = false;
  _Verdict _verdict = _Verdict.none;
  _CheckRow? _exitRow;
  _CheckRow? _realRow;
  _CheckRow? _ipv6Row;

  /// A Dio that always bypasses the proxy, so it reports the machine's real
  /// (untunneled) address. Mirrors the DIRECT client the panel API uses.
  Dio _directDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
    return dio;
  }

  Future<IpInfo?> _directIpv4() async {
    final sources = <String, IpInfo Function(Map<String, dynamic>)>{
      'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
      'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    };
    for (final entry in sources.entries) {
      try {
        final res = await _directDio()
            .get<Map<String, dynamic>>(
              entry.key,
              options: Options(responseType: ResponseType.json),
            )
            .timeout(const Duration(seconds: 8));
        final data = res.data;
        if (data != null) return entry.value(data);
      } catch (_) {
        // Try the next source.
      }
    }
    return null;
  }

  /// Attempts a request that can only succeed over IPv6. A non-null result means
  /// the device has a publicly reachable IPv6 address that an IPv4-only tunnel
  /// would not be covering — a potential leak.
  Future<String?> _directIpv6() async {
    try {
      final res = await _directDio()
          .get<String>(
            'https://api6.ipify.org',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 6));
      final ip = (res.data ?? '').trim();
      if (ip.contains(':')) return ip;
    } catch (_) {
      // No IPv6 connectivity — that's the good outcome here.
    }
    return null;
  }

  Future<void> _run() async {
    if (_running) return;
    final s = _stringsFor(context);
    final isConnected = ref.read(isStartProvider);
    if (!isConnected) {
      setState(() {
        _verdict = _Verdict.notConnected;
        _exitRow = null;
        _realRow = null;
        _ipv6Row = null;
      });
      return;
    }

    setState(() {
      _running = true;
      _verdict = _Verdict.none;
      _exitRow = _CheckRow(s.rowExitIp, state: _CheckState.running);
      _realRow = _CheckRow(s.rowRealIp, state: _CheckState.running);
      _ipv6Row = _CheckRow(s.rowIpv6, state: _CheckState.running);
    });

    // Exit IP is fetched through the app's proxy-aware client; real IP and IPv6
    // through DIRECT clients. Run them together.
    final results = await Future.wait([
      request.checkIp().then((r) => r.isError ? null : r.data),
      _directIpv4(),
      _directIpv6(),
    ]);
    if (!mounted) return;

    final exit = results[0] as IpInfo?;
    final real = results[1] as IpInfo?;
    final ipv6 = results[2] as String?;

    final exitRow = exit != null
        ? _CheckRow(s.rowExitIp, state: _CheckState.pass, value: _fmt(exit))
        : _CheckRow(
            s.rowExitIp,
            state: _CheckState.fail,
            value: s.couldNotDetermine,
          );

    final ipv4Leak = exit != null && real != null && exit.ip == real.ip;
    final realRow = real != null
        ? _CheckRow(
            s.rowRealIp,
            state: ipv4Leak ? _CheckState.fail : _CheckState.pass,
            value: _fmt(real),
            detail: exit != null
                ? (ipv4Leak ? s.sameAsReal : s.differsFromReal)
                : null,
          )
        : _CheckRow(
            s.rowRealIp,
            state: _CheckState.warn,
            value: s.couldNotDetermine,
          );

    final ipv6Row = ipv6 != null
        ? _CheckRow(
            s.rowIpv6,
            state: _CheckState.warn,
            value: ipv6,
            detail: s.ipv6Exposed,
          )
        : _CheckRow(s.rowIpv6, state: _CheckState.pass, value: s.ipv6None);

    final _Verdict verdict;
    if (exit == null && real == null) {
      verdict = _Verdict.error;
    } else if (ipv4Leak) {
      verdict = _Verdict.leak;
    } else if (exit == null || ipv6 != null) {
      // Tunnel exit couldn't be confirmed, or a v6 address is exposed.
      verdict = _Verdict.warn;
    } else {
      verdict = _Verdict.protected;
    }

    setState(() {
      _running = false;
      _verdict = verdict;
      _exitRow = exitRow;
      _realRow = realRow;
      _ipv6Row = ipv6Row;
    });
  }

  String _fmt(IpInfo info) {
    final cc = info.countryCode;
    return cc.isNotEmpty ? '${info.ip}  ·  $cc' : info.ip;
  }

  @override
  Widget build(BuildContext context) {
    final s = _stringsFor(context);
    final theme = Theme.of(context);
    final rows = [_exitRow, _realRow, _ipv6Row].whereType<_CheckRow>().toList();
    return CommonScaffold(
      title: s.title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(s.intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (_verdict != _Verdict.none) _VerdictBanner(verdict: _verdict, s: s),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    _CheckRowTile(row: rows[i]),
                    if (i < rows.length - 1) const Divider(height: 0),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.security),
            label: Text(_running ? s.running : s.run),
          ),
          const SizedBox(height: 16),
          Text(
            s.footnote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  final _Verdict verdict;
  final _Strings s;

  const _VerdictBanner({required this.verdict, required this.s});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon, String text) = switch (verdict) {
      _Verdict.protected => (Colors.green, Icons.verified_user, s.verdictProtected),
      _Verdict.leak => (theme.colorScheme.error, Icons.error, s.verdictLeak),
      _Verdict.warn => (Colors.orange, Icons.warning_amber, s.verdictWarn),
      _Verdict.error => (theme.colorScheme.error, Icons.cloud_off, s.verdictError),
      _Verdict.notConnected => (
          theme.colorScheme.onSurfaceVariant,
          Icons.vpn_key_off,
          s.notConnected,
        ),
      _Verdict.none => (theme.colorScheme.onSurfaceVariant, Icons.info, ''),
    };
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
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
          ],
        ),
      ),
    );
  }
}

class _CheckRowTile extends StatelessWidget {
  final _CheckRow row;

  const _CheckRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, Widget leading) = switch (row.state) {
      _CheckState.running => (
          theme.colorScheme.onSurfaceVariant,
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _CheckState.pass => (Colors.green, const Icon(Icons.check_circle)),
      _CheckState.warn => (Colors.orange, const Icon(Icons.warning_amber)),
      _CheckState.fail => (theme.colorScheme.error, const Icon(Icons.error)),
      _CheckState.pending => (
          theme.colorScheme.onSurfaceVariant,
          const Icon(Icons.circle_outlined),
        ),
    };
    return ListTile(
      leading: IconTheme.merge(
        data: IconThemeData(color: color),
        child: leading,
      ),
      title: Text(row.title, style: theme.textTheme.bodyMedium),
      subtitle: row.detail != null
          ? Text(row.detail!, style: TextStyle(color: color))
          : null,
      trailing: row.value != null
          ? Text(
              row.value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
