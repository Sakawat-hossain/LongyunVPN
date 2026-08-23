import 'package:longyunvpn/common/constant.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('$packageName/app');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late App app;
  late List<String> requested;
  String? Function(String packageName) respond = (_) => null;

  setUp(() {
    app = App();
    app.clearPackageIconCache();
    requested = [];
    respond = (name) => '/icons/$name.webp';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getPackageIcon') return null;
      final name = (call.arguments as Map)['packageName'] as String;
      requested.add(name);
      return respond(name);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    app.clearPackageIconCache();
  });

  group('package icon cache', () {
    test('resolves an icon and remembers it', () async {
      final first = await app.getPackageIcon('com.example.one');
      final second = await app.getPackageIcon('com.example.one');

      expect((first as FileImage).file.path, '/icons/com.example.one.webp');
      expect(second, same(first));
      // The point of the cache: the second read never reaches the platform.
      expect(requested, ['com.example.one']);
    });

    test('a warm entry is readable synchronously', () async {
      expect(app.hasPackageIcon('com.example.one'), isFalse);
      expect(app.cachedPackageIcon('com.example.one'), isNull);

      await app.getPackageIcon('com.example.one');

      expect(app.hasPackageIcon('com.example.one'), isTrue);
      expect(
        (app.cachedPackageIcon('com.example.one') as FileImage).file.path,
        '/icons/com.example.one.webp',
      );
    });

    test('concurrent requests for one package share a single call', () async {
      final results = await Future.wait([
        app.getPackageIcon('com.example.one'),
        app.getPackageIcon('com.example.one'),
        app.getPackageIcon('com.example.one'),
      ]);

      expect(requested, ['com.example.one']);
      expect(results[1], same(results[0]));
      expect(results[2], same(results[0]));
    });

    test('different packages are cached independently', () async {
      await app.getPackageIcon('com.example.one');
      await app.getPackageIcon('com.example.two');
      await app.getPackageIcon('com.example.one');

      expect(requested, ['com.example.one', 'com.example.two']);
    });

    test('an empty package name resolves to null without a call', () async {
      expect(await app.getPackageIcon(''), isNull);
      expect(requested, isEmpty);
    });

    test('a package with no icon is remembered as a miss', () async {
      respond = (_) => null;

      expect(await app.getPackageIcon('com.example.none'), isNull);
      expect(await app.getPackageIcon('com.example.none'), isNull);

      // Remembered, so a package that will never have an icon is not asked
      // about again on every rebuild.
      expect(requested, ['com.example.none']);
    });

    test('a platform error is remembered as a miss, not rethrown', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        requested.add((call.arguments as Map)['packageName'] as String);
        throw PlatformException(code: 'boom');
      });

      expect(await app.getPackageIcon('com.example.bad'), isNull);
      expect(await app.getPackageIcon('com.example.bad'), isNull);
      expect(requested, ['com.example.bad']);
    });

    test('eviction forces the next read back to the platform', () async {
      // Invalidation path: the native side names the icon file after the
      // package's lastUpdateTime and deletes the old one, so an app update
      // leaves the cached FileImage pointing at a file that is gone. The widget
      // notices via an image load error and evicts; the refetch must pick up
      // the new path rather than the remembered one.
      final before = await app.getPackageIcon('com.example.one');
      expect((before as FileImage).file.path, '/icons/com.example.one.webp');

      respond = (name) => '/icons/${name}_v2.webp';
      app.evictPackageIcon('com.example.one');

      expect(app.hasPackageIcon('com.example.one'), isFalse);
      final after = await app.getPackageIcon('com.example.one');
      expect((after as FileImage).file.path, '/icons/com.example.one_v2.webp');
      expect(requested, ['com.example.one', 'com.example.one']);
    });

    test('evicting an unknown package is harmless', () async {
      app.evictPackageIcon('com.example.never-seen');
      expect(app.hasPackageIcon('com.example.never-seen'), isFalse);
    });
  });
}
