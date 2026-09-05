import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/models/models.dart';

/// The sidebar starts expanded so a first-run window names its destinations
/// instead of showing a column of unlabelled icons. The menu button collapses
/// it from there.
///
/// Worth pinning: the value lives in a freezed @Default, so it is only as good
/// as the last code generation, and getting it wrong is invisible to anyone
/// whose config was saved before the change — which includes every developer
/// machine this would be looked at on.
void main() {
  group('sidebar labels', () {
    test('a fresh install starts with the menu expanded', () {
      expect(const AppSettingProps().showLabel, isTrue);
    });

    test('the menu button can collapse it', () {
      final collapsed = const AppSettingProps().copyWith(showLabel: false);
      expect(collapsed.showLabel, isFalse);
    });

    test('a saved preference survives, rather than being reset to the default',
        () {
      // A default applies only where nothing was stored. Anyone who collapsed
      // the sidebar in an earlier version keeps it collapsed.
      final stored = AppSettingProps.fromJson(
        const AppSettingProps().copyWith(showLabel: false).toJson(),
      );
      expect(stored.showLabel, isFalse);
    });

    test('a config written before this field existed gets the new default', () {
      final legacy = const AppSettingProps().toJson()..remove('showLabel');
      expect(AppSettingProps.fromJson(legacy).showLabel, isTrue);
    });
  });
}
