import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  // Both icons are always mounted and cross-faded, so presence proves nothing -
  // only the opacity says which one a user can actually see.
  double visibilityOf(WidgetTester tester, IconData icon) {
    return tester
        .widget<Opacity>(
          find
              .ancestor(of: find.byIcon(icon), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
  }

  testWidgets('shows power, not play, while disconnected', (tester) async {
    await pumpButton(tester, runTime: null);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(visibilityOf(tester, Icons.power_settings_new), 1);
    expect(visibilityOf(tester, Icons.verified_user), 0);
  });

  testWidgets('turns into a shield once connected', (tester) async {
    await pumpButton(tester, runTime: 0);
    await tester.pump(const Duration(milliseconds: 400));

    // The power symbol says what pressing does, which is the wrong job once the
    // tunnel is up and the timer beside it already reports that it is running.
    expect(visibilityOf(tester, Icons.verified_user), 1);
    expect(visibilityOf(tester, Icons.power_settings_new), 0);
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
