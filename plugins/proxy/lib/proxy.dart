import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import 'proxy_platform_interface.dart';

enum ProxyTypes { http, https, socks }

typedef ProxyProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
});

typedef ProxyExecutableChecker = Future<bool> Function(String executable);

@immutable
class ProxyCommand {
  final String executable;
  final List<String> args;
  final bool runInShell;

  const ProxyCommand(
    this.executable,
    this.args, {
    this.runInShell = false,
  });
}

enum LinuxProxyBackend {
  gnome,
  mate,
  kde,
}

/// The three manual proxies macOS keeps per network service.
enum MacosProxyKind {
  web('-getwebproxy', '-setwebproxystate'),
  secureWeb('-getsecurewebproxy', '-setsecurewebproxystate'),
  socks('-getsocksfirewallproxy', '-setsocksfirewallproxystate');

  final String getFlag;
  final String setStateFlag;

  const MacosProxyKind(this.getFlag, this.setStateFlag);
}

class Proxy extends ProxyPlatform {
  static String url = '127.0.0.1';

  final ProxyProcessRunner _processRunner;
  final ProxyExecutableChecker _executableChecker;

  Proxy({
    ProxyProcessRunner? processRunner,
    ProxyExecutableChecker? executableChecker,
  })  : _processRunner = processRunner ?? Process.run,
        _executableChecker = executableChecker ?? _hasExecutable;

  @override
  Future<bool?> startProxy(
    int port, [
    List<String> bypassDomain = const [],
  ]) async {
    return switch (Platform.operatingSystem) {
      'macos' => await _startProxyWithMacos(port, bypassDomain),
      'linux' => await _startProxyWithLinux(port, bypassDomain),
      'windows' => await ProxyPlatform.instance.startProxy(port, bypassDomain),
      String() => false,
    };
  }

  // Stop only ever undoes a proxy of ours: 127.0.0.1 on our port. It runs on
  // every launch, not just on disconnect, and it used to switch the proxy off
  // unconditionally - so opening the app to check an account turned off a
  // running Clash Verge, a company proxy, and on macOS the PAC setting of every
  // network service, which start never even touched. Windows applies the same
  // rule natively (see windows/system_proxy.h).
  @override
  Future<bool?> stopProxy([int? port]) async {
    return switch (Platform.operatingSystem) {
      'macos' => await stopMacosProxy(port),
      'linux' => await _stopProxyWithLinux(port),
      'windows' => await ProxyPlatform.instance.stopProxy(port),
      String() => false,
    };
  }

  // The port this process last pointed the system at. Recognises our proxy
  // when the port setting was changed while it was on.
  int? _appliedPort;

  Set<int> _ownedPorts(int? port) => {
        if (port != null) port,
        if (_appliedPort != null) _appliedPort!,
      };

  Future<bool> _startProxyWithLinux(int port, List<String> bypassDomain) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null || homeDir.isEmpty) {
      return false;
    }
    final commands = await _resolveLinuxStartCommands(
      port,
      bypassDomain,
      desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
      homeDir: homeDir,
    );
    if (commands.isEmpty) {
      return false;
    }
    final applied = await _runCommands(commands);
    if (applied) _appliedPort = port;
    return applied;
  }

  Future<bool> _stopProxyWithLinux(int? port) async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null || homeDir.isEmpty) {
      return false;
    }
    return stopLinuxProxy(
      port,
      desktop: Platform.environment['XDG_CURRENT_DESKTOP'],
      homeDir: homeDir,
    );
  }

  @visibleForTesting
  Future<bool> stopLinuxProxy(
    int? port, {
    required String? desktop,
    required String homeDir,
  }) async {
    final ports = _ownedPorts(port);
    if (ports.isEmpty) {
      return true;
    }
    final backend = await _resolveLinuxBackend(desktop);
    if (backend == null) {
      return false;
    }
    final bool ours;
    final List<ProxyCommand> commands;
    switch (backend) {
      case LinuxProxyBackend.gnome:
      case LinuxProxyBackend.mate:
        final schema = backend == LinuxProxyBackend.gnome
            ? 'org.gnome.system.proxy'
            : 'org.mate.system.proxy';
        ours = await _isGSettingsProxyOurs(schema, ports);
        commands = _buildGSettingsStopCommands(schemaPrefix: schema);
      case LinuxProxyBackend.kde:
        final writer = await _resolveKdeConfigWriter();
        ours = await _isKdeProxyOurs(
          homeDir: homeDir,
          reader: writer.replaceFirst('kwriteconfig', 'kreadconfig'),
          ports: ports,
        );
        commands = _buildKdeStopCommands(homeDir: homeDir, executable: writer);
    }
    if (!ours) {
      _appliedPort = null;
      return true;
    }
    final cleared = await _runCommands(commands);
    if (cleared) _appliedPort = null;
    return cleared;
  }

  Future<bool> _isGSettingsProxyOurs(String schema, Set<int> ports) async {
    final mode = await _read('gsettings', ['get', schema, 'mode']);
    if (_unquoteGVariant(mode) != 'manual') {
      return false;
    }
    final host = await _read('gsettings', ['get', '$schema.http', 'host']);
    final port = await _read('gsettings', ['get', '$schema.http', 'port']);
    return _unquoteGVariant(host) == url &&
        ports.contains(int.tryParse(_unquoteGVariant(port) ?? ''));
  }

  Future<bool> _isKdeProxyOurs({
    required String homeDir,
    required String reader,
    required Set<int> ports,
  }) async {
    List<String> key(String name) => [
          '--file',
          join(homeDir, '.config', 'kioslaverc'),
          '--group',
          'Proxy Settings',
          '--key',
          name,
        ];
    final type = await _read(reader, key('ProxyType'));
    if (type?.trim() != '1') {
      return false;
    }
    final http = await _read(reader, key('httpProxy'));
    return isOurKdeProxyForTest(http, ports);
  }

  /// Runs a read-only query; null if it could not be answered. An unanswered
  /// query means "not ours": leaving a proxy of ours on is recoverable with one
  /// click, and switching someone else's off is the bug this guards against.
  Future<String?> _read(String executable, List<String> args) async {
    try {
      final result = await _processRunner(executable, args);
      if (result.exitCode != 0) return null;
      return result.stdout.toString();
    } catch (_) {
      return null;
    }
  }

  static String? _unquoteGVariant(String? value) {
    if (value == null) return null;
    var text = value.trim();
    // gsettings prints integers bare, strings quoted, and some types prefixed.
    if (text.startsWith('uint32 ')) text = text.substring(7);
    if (text.length >= 2 &&
        (text.startsWith("'") && text.endsWith("'") ||
            text.startsWith('"') && text.endsWith('"'))) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  Future<bool> _startProxyWithMacos(int port, List<String> bypassDomain) async {
    final devices = await _getNetworkDeviceListWithMacos();
    final commands = devices.expand(
      (dev) => _buildMacosStartCommands(
        dev,
        port,
        bypassDomain,
      ),
    );
    final applied = await _runCommands(commands);
    if (applied) _appliedPort = port;
    return applied;
  }

  @visibleForTesting
  Future<bool> stopMacosProxy(int? port) async {
    final ports = _ownedPorts(port);
    if (ports.isEmpty) {
      return true;
    }
    final devices = await _getNetworkDeviceListWithMacos();
    final commands = <ProxyCommand>[];
    for (final dev in devices) {
      final owned = <MacosProxyKind>[];
      for (final kind in MacosProxyKind.values) {
        final out = await _read('/usr/sbin/networksetup', [kind.getFlag, dev]);
        if (out != null && isOurMacosProxyForTest(out, ports)) {
          owned.add(kind);
        }
      }
      commands.addAll(_buildMacosStopCommands(dev, owned));
    }
    final cleared = await _runCommands(commands);
    if (cleared) _appliedPort = null;
    return cleared;
  }

  Future<List<String>> _getNetworkDeviceListWithMacos() async {
    final res = await _processRunner(
      '/usr/sbin/networksetup',
      ['-listallnetworkservices'],
    );
    if (res.exitCode != 0) {
      return [];
    }
    return _parseMacosNetworkServices(res.stdout.toString());
  }

  Future<bool> _runCommands(Iterable<ProxyCommand> commands) async {
    try {
      for (final command in commands) {
        final result = await _processRunner(
          command.executable,
          command.args,
          runInShell: command.runInShell,
        );
        if (result.exitCode != 0) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ProxyCommand>> _resolveLinuxStartCommands(
    int port,
    List<String> bypassDomain, {
    required String? desktop,
    required String homeDir,
  }) async {
    final backend = await _resolveLinuxBackend(desktop);
    if (backend == null) {
      return [];
    }
    return _buildLinuxStartCommands(
      port: port,
      bypassDomain: bypassDomain,
      desktop: desktop,
      homeDir: homeDir,
      backend: backend,
      kdeConfigWriter: await _resolveKdeConfigWriter(),
    );
  }

  Future<LinuxProxyBackend?> _resolveLinuxBackend(String? desktop) async {
    final preferredBackend = _preferredLinuxBackend(desktop);
    if (preferredBackend != null) {
      return preferredBackend;
    }
    for (final backend in LinuxProxyBackend.values) {
      if (await _isLinuxBackendAvailable(backend)) {
        return backend;
      }
    }
    return null;
  }

  Future<bool> _isLinuxBackendAvailable(LinuxProxyBackend backend) async {
    return switch (backend) {
      LinuxProxyBackend.gnome => await _executableChecker('gsettings'),
      LinuxProxyBackend.mate => await _executableChecker('gsettings'),
      LinuxProxyBackend.kde => await _executableChecker('kwriteconfig6') ||
          await _executableChecker('kwriteconfig5'),
    };
  }

  Future<String> _resolveKdeConfigWriter() async {
    if (await _executableChecker('kwriteconfig6')) {
      return 'kwriteconfig6';
    }
    return 'kwriteconfig5';
  }

  static Future<bool> _hasExecutable(String executable) async {
    final result = await Process.run('which', [executable]);
    return result.exitCode == 0;
  }

  static LinuxProxyBackend? _preferredLinuxBackend(String? desktop) {
    final desktops = _linuxDesktops(desktop);
    if (desktops.contains('KDE')) {
      return LinuxProxyBackend.kde;
    }
    if (desktops.contains('MATE')) {
      return LinuxProxyBackend.mate;
    }
    if (desktops.any(
      (desktop) =>
          const {'GNOME', 'CINNAMON', 'BUDGIE', 'UNITY'}.contains(desktop),
    )) {
      return LinuxProxyBackend.gnome;
    }
    return null;
  }

  static Set<String> _linuxDesktops(String? desktop) {
    if (desktop == null || desktop.isEmpty) {
      return {};
    }
    return desktop
        .split(':')
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static List<ProxyCommand> _buildLinuxStartCommands({
    required int port,
    required List<String> bypassDomain,
    required String? desktop,
    required String homeDir,
    LinuxProxyBackend? backend,
    String kdeConfigWriter = 'kwriteconfig5',
    Set<String>? availableExecutables,
  }) {
    final resolvedBackend = backend ??
        _resolveLinuxBackendForBuild(
          desktop: desktop,
          availableExecutables: availableExecutables,
        );
    if (resolvedBackend == null) {
      return [];
    }
    return switch (resolvedBackend) {
      LinuxProxyBackend.gnome => _buildGSettingsStartCommands(
          port: port,
          bypassDomain: bypassDomain,
          schemaPrefix: 'org.gnome.system.proxy',
        ),
      LinuxProxyBackend.mate => _buildGSettingsStartCommands(
          port: port,
          bypassDomain: bypassDomain,
          schemaPrefix: 'org.mate.system.proxy',
        ),
      LinuxProxyBackend.kde => _buildKdeStartCommands(
          port: port,
          bypassDomain: bypassDomain,
          homeDir: homeDir,
          executable: _resolveKdeConfigWriterForBuild(
            availableExecutables,
            fallback: kdeConfigWriter,
          ),
        ),
    };
  }

  static LinuxProxyBackend? _resolveLinuxBackendForBuild({
    required String? desktop,
    required Set<String>? availableExecutables,
  }) {
    final preferredBackend = _preferredLinuxBackend(desktop);
    if (preferredBackend != null) {
      return preferredBackend;
    }
    if (availableExecutables == null) {
      return LinuxProxyBackend.gnome;
    }
    for (final backend in LinuxProxyBackend.values) {
      if (_isLinuxBackendAvailableForBuild(backend, availableExecutables)) {
        return backend;
      }
    }
    return null;
  }

  static bool _isLinuxBackendAvailableForBuild(
    LinuxProxyBackend backend,
    Set<String> availableExecutables,
  ) {
    return switch (backend) {
      LinuxProxyBackend.gnome => availableExecutables.contains('gsettings'),
      LinuxProxyBackend.mate => availableExecutables.contains('gsettings'),
      LinuxProxyBackend.kde => availableExecutables.contains('kwriteconfig6') ||
          availableExecutables.contains('kwriteconfig5'),
    };
  }

  static String _resolveKdeConfigWriterForBuild(
    Set<String>? availableExecutables, {
    required String fallback,
  }) {
    if (availableExecutables?.contains('kwriteconfig6') ?? false) {
      return 'kwriteconfig6';
    }
    if (availableExecutables?.contains('kwriteconfig5') ?? false) {
      return 'kwriteconfig5';
    }
    return fallback;
  }

  static List<ProxyCommand> _buildGSettingsStartCommands({
    required int port,
    required List<String> bypassDomain,
    required String schemaPrefix,
  }) {
    final commands = <ProxyCommand>[
      ProxyCommand(
        'gsettings',
        ['set', schemaPrefix, 'mode', 'manual'],
      ),
      ProxyCommand(
        'gsettings',
        [
          'set',
          schemaPrefix,
          'ignore-hosts',
          _formatGSettingsStringList(bypassDomain),
        ],
      ),
    ];
    for (final type in ProxyTypes.values) {
      commands.addAll([
        ProxyCommand(
          'gsettings',
          [
            'set',
            '$schemaPrefix.${type.name}',
            'host',
            url,
          ],
        ),
        ProxyCommand(
          'gsettings',
          [
            'set',
            '$schemaPrefix.${type.name}',
            'port',
            '$port',
          ],
        ),
      ]);
    }
    return commands;
  }

  static List<ProxyCommand> _buildGSettingsStopCommands({
    required String schemaPrefix,
  }) {
    return [
      ProxyCommand(
        'gsettings',
        ['set', schemaPrefix, 'mode', 'none'],
      ),
    ];
  }

  static List<ProxyCommand> _buildKdeStartCommands({
    required int port,
    required List<String> bypassDomain,
    required String homeDir,
    required String executable,
  }) {
    final configDir = join(homeDir, '.config');
    final commands = <ProxyCommand>[];
    commands.addAll([
      ProxyCommand(
        executable,
        [
          '--file',
          join(configDir, 'kioslaverc'),
          '--group',
          'Proxy Settings',
          '--key',
          'ProxyType',
          '1',
        ],
      ),
      ProxyCommand(
        executable,
        [
          '--file',
          join(configDir, 'kioslaverc'),
          '--group',
          'Proxy Settings',
          '--key',
          'NoProxyFor',
          bypassDomain.join(','),
        ],
      ),
    ]);
    for (final type in ProxyTypes.values) {
      commands.add(
        ProxyCommand(
          executable,
          [
            '--file',
            join(configDir, 'kioslaverc'),
            '--group',
            'Proxy Settings',
            '--key',
            '${type.name}Proxy',
            '${type.name}://$url:$port',
          ],
        ),
      );
    }
    return commands;
  }

  static List<ProxyCommand> _buildKdeStopCommands({
    required String homeDir,
    required String executable,
  }) {
    return [
      ProxyCommand(
        executable,
        [
          '--file',
          join(homeDir, '.config', 'kioslaverc'),
          '--group',
          'Proxy Settings',
          '--key',
          'ProxyType',
          '0',
        ],
      ),
    ];
  }

  static String _formatGSettingsStringList(List<String> values) {
    if (values.isEmpty) {
      return '[]';
    }
    final escaped = values.map((value) => "'${value.replaceAll("'", "\\'")}'");
    return '[${escaped.join(', ')}]';
  }

  static List<ProxyCommand> _buildMacosStartCommands(
    String dev,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setwebproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setwebproxystate', dev, 'on'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsecurewebproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsecurewebproxystate', dev, 'on'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsocksfirewallproxy', dev, url, '$port'],
      ),
      ProxyCommand(
        '/usr/sbin/networksetup',
        ['-setsocksfirewallproxystate', dev, 'on'],
      ),
      _buildMacosProxyBypassCommand(dev, bypassDomain),
    ];
  }

  // Switches off, on one service, only the proxies found pointing at us - and
  // never the automatic (PAC) setting, which start does not touch either.
  static List<ProxyCommand> _buildMacosStopCommands(
    String dev,
    List<MacosProxyKind> owned,
  ) {
    if (owned.isEmpty) {
      return const [];
    }
    return [
      for (final kind in owned)
        ProxyCommand('/usr/sbin/networksetup', [kind.setStateFlag, dev, 'off']),
      _buildMacosProxyBypassCommand(dev, const []),
    ];
  }

  /// Whether `networksetup -get*proxy` output describes 127.0.0.1 on one of
  /// [ports], switched on.
  @visibleForTesting
  static bool isOurMacosProxyForTest(String stdout, Set<int> ports) {
    final fields = <String, String>{};
    for (final line in stdout.split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      fields[line.substring(0, colon).trim()] =
          line.substring(colon + 1).trim();
    }
    return fields['Enabled'] == 'Yes' &&
        fields['Server'] == url &&
        ports.contains(int.tryParse(fields['Port'] ?? ''));
  }

  /// Whether a KDE `httpProxy` value is 127.0.0.1 on one of [ports]. Start
  /// writes `http://127.0.0.1:7890`; KDE's own settings page writes the port
  /// after a space instead.
  @visibleForTesting
  static bool isOurKdeProxyForTest(String? value, Set<int> ports) {
    if (value == null) return false;
    var text = value.trim();
    final scheme = text.indexOf('://');
    if (scheme >= 0) text = text.substring(scheme + 3);
    final separator = text.lastIndexOf(RegExp('[: ]'));
    if (separator <= 0) return false;
    return text.substring(0, separator) == url &&
        ports.contains(int.tryParse(text.substring(separator + 1)));
  }

  static ProxyCommand _buildMacosProxyBypassCommand(
    String dev,
    List<String> bypassDomain,
  ) {
    return ProxyCommand(
      '/usr/sbin/networksetup',
      [
        '-setproxybypassdomains',
        dev,
        if (bypassDomain.isEmpty) 'Empty' else ...bypassDomain,
      ],
    );
  }

  static List<String> _parseMacosNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }

  @visibleForTesting
  static List<ProxyCommand> buildLinuxStartCommandsForTest({
    required int port,
    required List<String> bypassDomain,
    required String? desktop,
    required String homeDir,
    Set<String>? availableExecutables,
  }) {
    return _buildLinuxStartCommands(
      port: port,
      bypassDomain: bypassDomain,
      desktop: desktop,
      homeDir: homeDir,
      availableExecutables: availableExecutables,
    );
  }

  @visibleForTesting
  static List<String> parseMacosNetworkServicesForTest(String stdout) {
    return _parseMacosNetworkServices(stdout);
  }

  @visibleForTesting
  static ProxyCommand buildMacosProxyBypassCommandForTest(
    String dev,
    List<String> bypassDomain,
  ) {
    return _buildMacosProxyBypassCommand(dev, bypassDomain);
  }
}
