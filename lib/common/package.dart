import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';

extension PackageInfoExtension on PackageInfo {
  /// User-Agent sent when fetching subscriptions.
  ///
  /// Panels pick which subscription *format* to serve from this string, so the
  /// client token matters a lot. Xboard, for example, ships a `Clash` handler
  /// (flag `clash`) that can only emit shadowsocks/vmess/trojan/socks/http, and
  /// a separate `ClashMeta` handler (flags `meta`, `verge`, `flclash`, ...) that
  /// also emits vless, hysteria/hysteria2, tuic, anytls and mieru. It matches
  /// flags longest-first and takes the first hit.
  ///
  /// The old token here was `clash-verge`, which contains BOTH `clash` and
  /// `verge` — same length, so which handler won was a coin flip. Losing that
  /// coin flip means the panel silently drops every VLESS/Reality, Hysteria2,
  /// TUIC and AnyTLS node from the subscription.
  ///
  /// `flclash` is unambiguous: it is a ClashMeta flag, and at 7 characters it is
  /// matched before the 5-character `clash`, so the Meta format always wins.
  /// The core here is mihomo/Clash.Meta, so claiming Meta support is accurate.
  String get ua => [
        '$appName/v$version',
        'flclash',
        'Platform/${Platform.operatingSystem}',
      ].join(' ');
}
