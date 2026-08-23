import 'package:longyunvpn/common/constant.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:longyunvpn/widgets/icon.dart';
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

  setUp(() {
    app = App();
    app.clearPackageIconCache();
    requested = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'getPackageIcon') return null;
      requested.add((call.arguments as Map)['packageName'] as String);
      return '/icons/${requested.last}.webp';
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    app.clearPackageIconCache();
  });

  Widget host(String packageName) => MaterialApp(
    home: PackageIcon(packageName: packageName, size: 42, source: app),
  );

  testWidgets('asks the platform once, then survives rebuilds without asking '
      'again', (tester) async {
    await tester.pumpWidget(host('com.example.one'));
    await tester.pumpAndSettle();

    expect(requested, ['com.example.one']);

    // What the old FutureBuilder got wrong: each rebuild made a new Future and
    // so a new channel call. These rebuilds must be free.
    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(host('com.example.one'));
      await tester.pump();
    }

    expect(requested, ['com.example.one']);
  });

  testWidgets('keeps showing the icon across a rebuild', (tester) async {
    await tester.pumpWidget(host('com.example.one'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);

    // The FutureBuilder version dropped back to an empty box on every rebuild
    // while the new Future resolved, which is what made the icon blink.
    await tester.pumpWidget(host('com.example.one'));
    await tester.pump(Duration.zero);

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('paints from a warm cache on the very first frame', (
    tester,
  ) async {
    await app.getPackageIcon('com.example.one');
    requested.clear();

    await tester.pumpWidget(host('com.example.one'));
    // No settle: a cached icon must be there before any async work runs.
    await tester.pump(Duration.zero);

    expect(find.byType(Image), findsOneWidget);
    expect(requested, isEmpty);
  });

  testWidgets('follows the package name when a row is recycled', (
    tester,
  ) async {
    await tester.pumpWidget(host('com.example.one'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host('com.example.two'));
    await tester.pumpAndSettle();

    expect(requested, ['com.example.one', 'com.example.two']);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, '/icons/com.example.two.webp');
  });

  testWidgets('renders an empty box of the requested size with no icon', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    await tester.pumpWidget(host('com.example.none'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    final box = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(PackageIcon),
        matching: find.byType(SizedBox),
      ),
    );
    expect(box.width, 42);
    expect(box.height, 42);
  });

  testWidgets('an unreadable icon file is evicted and resolved again', (
    tester,
  ) async {
    // The invalidation path. The native side names each icon file after the
    // package's lastUpdateTime and deletes the previous one, so after an app
    // update a cached FileImage points at a file that is gone. Decoding fails,
    // and the widget has to drop the stale entry and ask the platform again
    // rather than showing a blank square until the next restart.
    //
    // The failure is driven through errorBuilder directly: a real decode needs
    // real file I/O, which never completes inside testWidgets' fake-async zone.
    var call = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      call++;
      return '/icons/com.example.one_v$call.webp';
    });

    await tester.pumpWidget(host('com.example.one'));
    await tester.pumpAndSettle();

    expect(call, 1);
    expect(app.hasPackageIcon('com.example.one'), isTrue);

    final image = tester.widget<Image>(find.byType(Image));
    image.errorBuilder!(
      tester.element(find.byType(Image)),
      Object(),
      StackTrace.empty,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(call, 2, reason: 'the failed load should trigger exactly one retry');
    expect(
      (tester.widget<Image>(find.byType(Image)).image as FileImage).file.path,
      '/icons/com.example.one_v2.webp',
    );
  });

  testWidgets('a second failure is not retried, so a broken icon cannot loop', (
    tester,
  ) async {
    var call = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      call++;
      return '/icons/com.example.one_v$call.webp';
    });

    await tester.pumpWidget(host('com.example.one'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      final image = tester.widget<Image>(find.byType(Image));
      image.errorBuilder!(
        tester.element(find.byType(Image)),
        Object(),
        StackTrace.empty,
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }

    expect(call, 2, reason: 'one retry only, however many times it fails');
  });
}
