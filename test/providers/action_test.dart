import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/providers/action.dart';
import 'package:longyunvpn/providers/config.dart';
import 'package:longyunvpn/providers/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ProfilesAction', () {
    test('keeps edited profile data when remote update fails', () async {
      final original = Profile.normal(label: 'old label', url: 'bad-url');
      final edited = original.copyWith(
        label: 'new label',
        url: 'still-bad-url',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([original])),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profilesProvider).getProfile(original.id),
        original,
      );

      await expectLater(
        container.read(profilesActionProvider.notifier).updateProfile(edited),
        throwsA(anything),
      );

      final profile = container.read(profilesProvider).getProfile(original.id);
      expect(profile?.label, edited.label);
      expect(profile?.url, edited.url);
    });

    test('dedupe moves the selection off a duplicate it deletes', () {
      // The selected profile being the later copy of a URL is exactly the
      // case that used to leave the selection pointing at nothing.
      final first = Profile.normal(label: 'kept', url: 'https://sub/a');
      final dup = Profile.normal(label: 'dup', url: 'https://sub/a');
      final other = Profile.normal(label: 'other', url: 'https://sub/b');
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => dup.id),
          profilesProvider.overrideWith(
            () => _TestProfiles([first, dup, other]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(profilesActionProvider.notifier).dedupeProfiles();

      expect(container.read(profilesProvider).map((p) => p.id), [
        first.id,
        other.id,
      ]);
      expect(container.read(currentProfileIdProvider), first.id);
    });

    test('dedupe leaves an unaffected selection alone', () {
      final first = Profile.normal(label: 'kept', url: 'https://sub/a');
      final dup = Profile.normal(label: 'dup', url: 'https://sub/a');
      final other = Profile.normal(label: 'other', url: 'https://sub/b');
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => other.id),
          profilesProvider.overrideWith(
            () => _TestProfiles([first, dup, other]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(profilesActionProvider.notifier).dedupeProfiles();

      expect(container.read(currentProfileIdProvider), other.id);
      expect(container.read(profilesProvider), hasLength(2));
    });
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }

  @override
  void del(int id) {
    state = state.where((item) => item.id != id).toList();
  }
}
