import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:longyunvpn/common/constant.dart';
import 'package:longyunvpn/common/measure.dart';
import 'package:longyunvpn/l10n/l10n.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:longyunvpn/views/dashboard/widgets/start_button.dart';

/// The connect button is the one control a first-time user has to find, and
/// while disconnected it used to be a bare circle with a play glyph: a media
/// metaphor, no label, and the same colour as its connected state.
///
/// What is pinned here is the resting state, because that is the one that was
/// wrong. A button that only explains itself after you have already pressed it
/// explains nothing.
void main() {
  Future<void> pumpButton(WidgetTester tester, {required int? runTime}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The button hides itself entirely when there is no profile.
          profilesProvider.overrideWith(() => _OneProfile()),
          // isStart is derived from runTime: null is stopped, a value is running.
          runTimeProvider.overrideWith(() => _RunTime(runTime)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // StartButton measures its label to size the pill.
                globalState.measure = Measure.of(context, 1);
                return const StartButton();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('is the icon alone while disconnected', (tester) async {
    await pumpButton(tester, runTime: null);
    await tester.pump(const Duration(milliseconds: 400));

    // No words at rest - the button is a circle, and the tooltip names the
    // action. Any visible label here would make it a pill again.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.isNotEmpty);
    expect(labels, isEmpty);

    // And it is a circle, not a collapsed pill: the FAB's own 56pt box, with
    // no leftover label width holding it open.
    final size = tester.getSize(find.byType(FloatingActionButton));
    expect(size.width, closeTo(size.height, 0.5));
    expect(size.height, 56);
  });

  Color? iconColour(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.power_settings_new)).color;

  FloatingActionButton fab(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

  testWidgets('shows power, not play, in both states', (tester) async {
    for (final runTime in [null, 0]) {
      await pumpButton(tester, runTime: runTime);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('the glyph takes the brand red once connected', (tester) async {
    await pumpButton(tester, runTime: null);
    await tester.pump(const Duration(milliseconds: 400));
    expect(iconColour(tester), isNot(appBrandColor));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpButton(tester, runTime: 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(iconColour(tester), appBrandColor);
  });

  testWidgets('the timer stays readable against the pill', (tester) async {
    // The running pill resolves light in this theme, and so does the scheme's
    // on-colour, so taking the text colour from the scheme drew the timer
    // light-on-light. Contrast has to come from the pill that got painted.
    await pumpButton(tester, runTime: 0);
    await tester.pump(const Duration(milliseconds: 400));

    // Read the colour the timer is actually painted in, not the one the button
    // declares. The button's foregroundColor was right all along; a text style
    // taken from the theme carries its own colour and quietly overrode it, so
    // asserting on the button passed while the timer stayed white on pink.
    final background = fab(tester).backgroundColor!;
    final label = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((text) => (text.data ?? '').isNotEmpty);
    final painted = label.style?.color;
    expect(painted, isNotNull, reason: 'timer has no explicit colour');
    final gap =
        (background.computeLuminance() - painted!.computeLuminance()).abs();
    expect(gap, greaterThan(0.4), reason: 'timer is not readable on the pill');
  });

  testWidgets('keeps the squircle corner, not a circle', (tester) async {
    await pumpButton(tester, runTime: null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(fab(tester).shape, isA<RoundedSuperellipseBorder>());
  });

  testWidgets('swaps the label for the timer once connected', (tester) async {
    await pumpButton(tester, runTime: 0);
    await tester.pump(const Duration(milliseconds: 400));

    // The timer appears where the resting state showed nothing at all.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.isNotEmpty);
    expect(labels, isNotEmpty);
  });

  testWidgets('resting and running do not look the same', (tester) async {
    await pumpButton(tester, runTime: null);
    await tester.pump(const Duration(milliseconds: 400));
    final resting = tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .backgroundColor;

    // Tear the tree down in between. Pumping a second ProviderScope over the
    // first keeps the same State alive, which would carry the first run's
    // animation value into the second and compare a state against itself.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpButton(tester, runTime: 0);
    await tester.pump(const Duration(milliseconds: 400));
    final running = tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .backgroundColor;

    expect(resting, isNotNull);
    expect(running, isNotNull);
    expect(resting, isNot(running));
  });
}

class _OneProfile extends Profiles {
  @override
  List<Profile> build() => [Profile.normal(label: 'test', url: 'http://x')];
}

class _RunTime extends RunTime {
  _RunTime(this.initial);

  final int? initial;

  @override
  int? build() => initial;
}
