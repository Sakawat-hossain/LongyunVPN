import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/constant.dart';
import 'package:longyunvpn/manager/window_manager.dart';

/// The desktop title bar carried nothing but the window buttons, so the app
/// showed its name nowhere once the window was open. It now shows the mark and
/// the brand name on the left.
///
/// The reason this is worth a test is the drag: the branding sits in a Stack
/// *above* the strip that starts the window drag, so without an IgnorePointer
/// it silently swallows the gesture and the most obvious place to grab the
/// window becomes the one place that does not work. Nothing about that is
/// visible in a screenshot — it only shows up when someone tries to move the
/// window — so it is pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() {
    calls = [];
    // WindowHeader asks the platform for its maximized/always-on-top state as
    // soon as it mounts, and reports a drag back to it; there is no platform in
    // a widget test, so record the calls instead.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'isMaximized' || 'isAlwaysOnTop' || 'isFullScreen' => false,
          _ => null,
        };
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    );
  });

  Future<void> pumpHeader(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(children: [WindowHeader()]),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the brand name in the title bar', (tester) async {
    await pumpHeader(tester);
    tester.takeException(); // asset decoding is not what this asserts

    expect(find.text(appBrandName), findsOneWidget);
  });

  testWidgets('shows the app mark next to it', (tester) async {
    await pumpHeader(tester);
    tester.takeException();

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((asset) => asset.assetName);

    expect(images, contains('assets/images/icon.png'));
  });

  testWidgets('the window still drags by its own name', (tester) async {
    await pumpHeader(tester);
    tester.takeException();
    calls.clear();

    // Drag starting on the brand label itself. The label sits above the strip
    // that starts the drag, so this only reaches the handle if the pointer
    // passes through it.
    // warnIfMissed is off because missing is the point: the pointer is supposed
    // to pass through the label and land on the drag strip behind it.
    await tester.drag(
      find.text(appBrandName),
      const Offset(60, 0),
      warnIfMissed: false,
    );
    // startDragging is async and queries the platform on its way through, so
    // let those round-trips finish before reading what was called.
    await tester.pumpAndSettle();

    expect(calls, contains('startDragging'));
  });

  test('the brand name is separate from the machine-facing app name', () {
    // appName feeds install paths, the Windows service, the core binary and
    // release filenames. Those must not pick up two CJK characters because the
    // title bar wanted a prettier label.
    expect(appName, 'LongyunVPN');
    expect(appBrandName, contains(appName));
    expect(appBrandName, isNot(appName));
  });
}
