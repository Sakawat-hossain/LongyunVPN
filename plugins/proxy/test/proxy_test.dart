import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:proxy/proxy.dart';

void main() {
  group('Linux proxy command builders', () {
    test('builds GNOME commands without duplicate port writes', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost', '127.0.0.1'],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      final portCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'port',
      );
      final hostCommands = commands.where(
        (command) => command.args.length == 4 && command.args[2] == 'host',
      );

      expect(portCommands, hasLength(3));
      expect(hostCommands, hasLength(3));
      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        "['localhost', '127.0.0.1']",
      );
    });

    test('builds empty GNOME ignore-hosts as an empty list', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: const [],
        desktop: 'GNOME',
        homeDir: '/home/user',
      );

      expect(
        commands
            .singleWhere(
              (command) =>
                  command.args.contains('org.gnome.system.proxy') &&
                  command.args.contains('ignore-hosts'),
            )
            .args
            .last,
        '[]',
      );
    });

    test('builds MATE commands with MATE proxy schema', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'MATE',
        homeDir: '/home/user',
      );

      expect(
        commands.any(
          (command) => command.args.contains('org.mate.system.proxy'),
        ),
        isTrue,
      );
      expect(
        commands.any(
          (command) => command.args.contains('org.gnome.system.proxy'),
        ),
        isFalse,
      );
    });

    test('falls back to GNOME gsettings commands for XFCE when available', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'XFCE',
        homeDir: '/home/user',
        availableExecutables: {'gsettings'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'gsettings',
      });
      expect(
        commands.any(
          (command) =>
              command.args.contains('org.gnome.system.proxy') &&
              command.args.contains('manual'),
        ),
        isTrue,
      );
    });

    test('prefers kwriteconfig6 for KDE when available', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'KDE',
        homeDir: '/home/user',
        availableExecutables: {'kwriteconfig6', 'kwriteconfig5'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'kwriteconfig6',
      });
    });

    test('falls back to kwriteconfig5 for KDE when kwriteconfig6 is missing',
        () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'KDE',
        homeDir: '/home/user',
        availableExecutables: {'kwriteconfig5'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'kwriteconfig5',
      });
    });

    test('uses available backend for unknown desktops', () {
      final commands = Proxy.buildLinuxStartCommandsForTest(
        port: 7890,
        bypassDomain: ['localhost'],
        desktop: 'UNKNOWN',
        homeDir: '/home/user',
        availableExecutables: {'kwriteconfig5'},
      );

      expect(commands.map((command) => command.executable).toSet(), {
        'kwriteconfig5',
      });
    });
  });

  group('macOS proxy command builders', () {
    test(
        'filters networksetup service list headers, disabled services, and blanks',
        () {
      final services = Proxy.parseMacosNetworkServicesForTest('''
An asterisk (*) denotes that a network service is disabled.
Wi-Fi
*Thunderbolt Bridge
USB 10/100/1000 LAN

''');

      expect(services, ['Wi-Fi', 'USB 10/100/1000 LAN']);
    });

    test('passes bypass domains as separate networksetup arguments', () {
      final command = Proxy.buildMacosProxyBypassCommandForTest(
        'Wi-Fi',
        ['localhost', '127.0.0.1'],
      );

      expect(command.executable, '/usr/sbin/networksetup');
      expect(command.args, [
        '-setproxybypassdomains',
        'Wi-Fi',
        'localhost',
        '127.0.0.1',
      ]);
    });

    test('uses Empty when clearing bypass domains', () {
      final command = Proxy.buildMacosProxyBypassCommandForTest(
        'Wi-Fi',
        const [],
      );

      expect(command.args, ['-setproxybypassdomains', 'Wi-Fi', 'Empty']);
    });
  });

  group('stopping only ever undoes our own proxy', () {
    const ours = '''
Enabled: Yes
Server: 127.0.0.1
Port: 7890
Authenticated Proxy Enabled: 0
''';
    const clashVerge = '''
Enabled: Yes
Server: 127.0.0.1
Port: 7897
Authenticated Proxy Enabled: 0
''';
    const off = '''
Enabled: No
Server: 127.0.0.1
Port: 7890
Authenticated Proxy Enabled: 0
''';

    test('macOS: reads networksetup output', () {
      expect(Proxy.isOurMacosProxyForTest(ours, {7890}), isTrue);
      expect(Proxy.isOurMacosProxyForTest(clashVerge, {7890}), isFalse);
      expect(Proxy.isOurMacosProxyForTest(off, {7890}), isFalse);
      expect(
        Proxy.isOurMacosProxyForTest(
          'Enabled: Yes\nServer: proxy.corp.example\nPort: 7890\n',
          {7890},
        ),
        isFalse,
      );
    });

    test("macOS: leaves another app's proxy and PAC alone", () async {
      final fake = _FakeSystem({
        '/usr/sbin/networksetup -listallnetworkservices':
            'An asterisk (*) denotes that a network service is disabled.\n'
                'Wi-Fi\n',
        '/usr/sbin/networksetup -getwebproxy Wi-Fi': clashVerge,
        '/usr/sbin/networksetup -getsecurewebproxy Wi-Fi': clashVerge,
        '/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi': clashVerge,
      });

      expect(await fake.proxy.stopMacosProxy(7890), isTrue);
      expect(fake.writes, isEmpty);
    });

    test('macOS: switches off only what points at us, never PAC', () async {
      final fake = _FakeSystem({
        '/usr/sbin/networksetup -listallnetworkservices': 'Wi-Fi\nEthernet\n',
        '/usr/sbin/networksetup -getwebproxy Wi-Fi': ours,
        '/usr/sbin/networksetup -getsecurewebproxy Wi-Fi': ours,
        '/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi': off,
        '/usr/sbin/networksetup -getwebproxy Ethernet': clashVerge,
        '/usr/sbin/networksetup -getsecurewebproxy Ethernet': clashVerge,
        '/usr/sbin/networksetup -getsocksfirewallproxy Ethernet': clashVerge,
      });

      expect(await fake.proxy.stopMacosProxy(7890), isTrue);
      expect(fake.writes, [
        '/usr/sbin/networksetup -setwebproxystate Wi-Fi off',
        '/usr/sbin/networksetup -setsecurewebproxystate Wi-Fi off',
        '/usr/sbin/networksetup -setproxybypassdomains Wi-Fi Empty',
      ]);
      expect(fake.writes.any((w) => w.contains('autoproxy')), isFalse);
    });

    test('macOS: a failed query counts as not ours', () async {
      final fake = _FakeSystem({
        '/usr/sbin/networksetup -listallnetworkservices': 'Wi-Fi\n',
      });

      expect(await fake.proxy.stopMacosProxy(7890), isTrue);
      expect(fake.writes, isEmpty);
    });

    test('macOS: with no port to go on, touches nothing', () async {
      final fake = _FakeSystem({
        '/usr/sbin/networksetup -listallnetworkservices': 'Wi-Fi\n',
        '/usr/sbin/networksetup -getwebproxy Wi-Fi': ours,
        '/usr/sbin/networksetup -getsecurewebproxy Wi-Fi': off,
        '/usr/sbin/networksetup -getsocksfirewallproxy Wi-Fi': off,
      });

      expect(await fake.proxy.stopMacosProxy(null), isTrue);
      expect(fake.writes, isEmpty);

      expect(await fake.proxy.stopMacosProxy(7891), isTrue);
      expect(fake.writes, isEmpty);
    });

    test('GNOME: resets the mode only when it is our manual proxy', () async {
      Map<String, String> gnome(String mode, String host, String port) => {
            'gsettings get org.gnome.system.proxy mode': mode,
            'gsettings get org.gnome.system.proxy.http host': host,
            'gsettings get org.gnome.system.proxy.http port': port,
          };

      final mine = _FakeSystem(gnome("'manual'\n", "'127.0.0.1'\n", '7890\n'));
      expect(
        await mine.proxy
            .stopLinuxProxy(7890, desktop: 'GNOME', homeDir: '/home/u'),
        isTrue,
      );
      expect(mine.writes, ['gsettings set org.gnome.system.proxy mode none']);

      for (final other in [
        gnome("'manual'\n", "'127.0.0.1'\n", '7897\n'),
        gnome("'manual'\n", "'proxy.corp.example'\n", '7890\n'),
        gnome("'auto'\n", "'127.0.0.1'\n", '7890\n'),
        gnome("'none'\n", "'127.0.0.1'\n", '7890\n'),
      ]) {
        final fake = _FakeSystem(other);
        await fake.proxy
            .stopLinuxProxy(7890, desktop: 'GNOME', homeDir: '/home/u');
        expect(fake.writes, isEmpty, reason: '$other is not ours');
      }
    });

    test('KDE: reads the value back with the matching kreadconfig', () async {
      final file = join('/home/u', '.config', 'kioslaverc');
      Map<String, String> kde(String type, String http) => {
            'kreadconfig6 --file $file --group Proxy Settings --key ProxyType':
                type,
            'kreadconfig6 --file $file --group Proxy Settings --key httpProxy':
                http,
          };

      final mine = _FakeSystem(
        kde('1\n', 'http://127.0.0.1:7890\n'),
        executables: {'kwriteconfig6'},
      );
      await mine.proxy.stopLinuxProxy(7890, desktop: 'KDE', homeDir: '/home/u');
      expect(mine.writes, [
        'kwriteconfig6 --file $file --group Proxy Settings --key ProxyType 0',
      ]);

      final theirs = _FakeSystem(
        kde('1\n', 'http://127.0.0.1 7897\n'),
        executables: {'kwriteconfig6'},
      );
      await theirs.proxy
          .stopLinuxProxy(7890, desktop: 'KDE', homeDir: '/home/u');
      expect(theirs.writes, isEmpty);
    });

    test('KDE: understands both ways the port is written', () {
      expect(
        Proxy.isOurKdeProxyForTest('http://127.0.0.1:7890', {7890}),
        isTrue,
      );
      expect(
        Proxy.isOurKdeProxyForTest('http://127.0.0.1 7890', {7890}),
        isTrue,
      );
      expect(
        Proxy.isOurKdeProxyForTest('http://10.0.0.1:7890', {7890}),
        isFalse,
      );
      expect(Proxy.isOurKdeProxyForTest('', {7890}), isFalse);
      expect(Proxy.isOurKdeProxyForTest(null, {7890}), isFalse);
    });
  });
}

/// Answers read-only queries from [answers] and records everything else as a
/// write. A query not in [answers] fails, as an unanswerable one would.
class _FakeSystem {
  final Map<String, String> answers;
  final Set<String> executables;
  final List<String> writes = [];

  _FakeSystem(this.answers, {this.executables = const {'gsettings'}});

  Proxy get proxy => Proxy(
        processRunner: (exe, args, {runInShell = false}) async {
          final line = [exe, ...args].join(' ');
          final answer = answers[line];
          if (answer != null) return ProcessResult(0, 0, answer, '');
          final isQuery = args.any((a) => a.startsWith('-get')) ||
              args.contains('-listallnetworkservices') ||
              (exe == 'gsettings' && args.first == 'get') ||
              exe.startsWith('kreadconfig');
          if (isQuery) return ProcessResult(0, 1, '', 'not answered');
          writes.add(line);
          return ProcessResult(0, 0, '', '');
        },
        executableChecker: (exe) async => executables.contains(exe),
      );
}
