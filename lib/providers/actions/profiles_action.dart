part of '../action.dart';

@Riverpod(keepAlive: true)
class ProfilesAction extends _$ProfilesAction {
  @override
  void build() {}

  void updateCurrentSelectedMap(String groupName, String proxyName) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile != null &&
        currentProfile.selectedMap[groupName] != proxyName) {
      final selectedMap = Map<String, String>.from(currentProfile.selectedMap)
        ..[groupName] = proxyName;
      ref
          .read(profilesProvider.notifier)
          .put(currentProfile.copyWith(selectedMap: selectedMap));
    }
  }

  Future<void> deleteProfile(int id) async {
    ref.read(profilesProvider.notifier).del(id);
    clearEffect(id);
    final currentProfileId = ref.read(currentProfileIdProvider);
    if (currentProfileId == id) {
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        final updateId = profiles.first.id;
        ref.read(currentProfileIdProvider.notifier).value = updateId;
      } else {
        ref.read(currentProfileIdProvider.notifier).value = null;
        ref.read(setupActionProvider.notifier).updateStatus(false);
      }
    }
  }

  Future<void> autoUpdateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (!profile.autoUpdate) continue;
      final isNotNeedUpdate = profile.lastUpdateDate
          ?.add(profile.autoUpdateDuration)
          .isBeforeNow;
      if (isNotNeedUpdate == false || profile.type == ProfileType.file) {
        continue;
      }
      try {
        await updateProfile(profile);
      } catch (e) {
        commonPrint.log(e.toString(), logLevel: LogLevel.warning);
      }
    }
  }

  void putProfile(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    final currentId = ref.read(currentProfileIdProvider);
    // Adopt the new profile when nothing is selected OR when the selection
    // points at a profile that no longer exists (deleted, or an id left behind
    // by an earlier install). The old check only tested for null, so a dangling
    // id meant the freshly imported subscription was never made current: the
    // core loaded no config, the Servers page stayed empty, and importing again
    // could not recover it.
    final currentExists =
        currentId != null &&
        ref.read(profilesProvider).any((p) => p.id == currentId);
    if (currentExists) return;
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
  }

  Future<void> updateProfiles() async {
    for (final profile in ref.read(profilesProvider)) {
      if (profile.type == ProfileType.file) continue;
      await updateProfile(profile);
    }
  }

  Future<void> updateProfile(
    Profile profile, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = true;
      }
      ref.read(profilesProvider.notifier).put(profile);
      final newProfile = await profile.update();
      ref.read(profilesProvider.notifier).put(newProfile);
      // Re-pull the account alongside the config. Refreshing used to fetch the
      // subscription file and nothing else, so plan, expiry, traffic counters
      // and the device allowance kept showing whatever was cached from sign-in
      // — a renewal or a device-limit change was invisible until the next
      // launch. Only for the profile that is the account's own subscription,
      // and never fatal: a failed account refresh must not fail the import.
      final subscribeUrl = ref.read(authProvider).subscribeInfo?.subscribeUrl;
      if (subscribeUrl != null && subscribeUrl == newProfile.url) {
        try {
          await ref.read(authProvider.notifier).refresh();
        } catch (e) {
          commonPrint.log(
            'profile refresh: account sync failed: $e',
            logLevel: LogLevel.warning,
          );
        }
      }
      if (profile.id == ref.read(currentProfileIdProvider)) {
        ref
            .read(setupActionProvider.notifier)
            .applyProfileDebounce(silence: true);
      }
    } finally {
      ref.read(isUpdatingProvider(profile.updatingKey).notifier).value = false;
    }
  }

  Future<void> addProfileFormFile() async {
    final platformFile = await globalState.safeRun(picker.pickerFile);
    final bytes = platformFile?.bytes;
    if (bytes == null) return;
    globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(currentPageLabelProvider.notifier).toProfiles();
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(label: platformFile?.name).saveFile(bytes);
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  void dedupeProfiles() {
    final profiles = ref.read(profilesProvider);
    final kept = <String, int>{};
    for (final profile in profiles) {
      if (profile.url.isEmpty) continue;
      final keptId = kept[profile.url];
      if (keptId == null) {
        kept[profile.url] = profile.id;
        continue;
      }
      // The duplicate being dropped can be the selected one. Deleting it
      // without moving the selection left the id pointing at nothing: no
      // profile, no config, an empty server list - and since the URL was
      // still present, signing in never re-imported it to recover.
      if (ref.read(currentProfileIdProvider) == profile.id) {
        ref.read(currentProfileIdProvider.notifier).value = keptId;
      }
      ref.read(profilesProvider.notifier).del(profile.id);
    }
  }

  /// Imports (or refreshes) the account's subscription at [url] and makes it
  /// the selected profile, deleting any profile for [replacedUrl].
  ///
  /// Importing alone is not enough: [putProfile] keeps whatever is already
  /// selected. After "Reset subscription URL" that was the old profile, whose
  /// credentials the reset had just revoked, so the device lost its connection
  /// at the moment the reset promised to keep it working. The same held for
  /// a second person signing in on a device: the first account stayed
  /// selected, and its plan is what they used.
  Future<void> adoptAccountProfile(String url, {String? replacedUrl}) async {
    await addProfileFormURL(url);
    int? adoptedId;
    for (final profile in ref.read(profilesProvider)) {
      if (profile.url == url) {
        adoptedId = profile.id;
        break;
      }
    }
    // Import failed; addProfileFormURL has already told the user why. Leave
    // everything else as it was rather than delete the only working profile.
    if (adoptedId == null) return;
    ref.read(currentProfileIdProvider.notifier).value = adoptedId;
    if (replacedUrl != null && replacedUrl.isNotEmpty && replacedUrl != url) {
      await removeProfilesForUrl(replacedUrl);
    }
  }

  /// Deletes every profile imported from [url].
  Future<void> removeProfilesForUrl(String url) async {
    final matching = ref
        .read(profilesProvider)
        .where((p) => p.url == url)
        .map((p) => p.id)
        .toList();
    for (final id in matching) {
      await deleteProfile(id);
    }
  }

  Future<void> addProfileFormURL(String url) async {
    if (globalState.navigatorKey.currentState?.canPop() ?? false) {
      globalState.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    ref.read(currentPageLabelProvider.notifier).value = PageLabel.profiles;
    final existingProfiles = ref
        .read(profilesProvider)
        .where((p) => p.url == url)
        .toList();
    if (existingProfiles.isNotEmpty) {
      final keep = existingProfiles.first;
      for (final dup in existingProfiles.skip(1)) {
        ref.read(profilesProvider.notifier).del(dup.id);
      }
      final updated = await globalState.loadingRun(
        tag: LoadingTag.profiles,
        () async {
          return keep.update();
        },
        title: currentAppLocalizations.addProfile,
      );
      if (updated != null) {
        putProfile(updated);
      }
      return;
    }
    final profile = await globalState.loadingRun(
      tag: LoadingTag.profiles,
      () async {
        return Profile.normal(url: url).update();
      },
      title: currentAppLocalizations.addProfile,
    );
    if (profile != null) {
      putProfile(profile);
    }
  }

  void setProfileAndAutoApply(Profile profile) {
    ref.read(profilesProvider.notifier).put(profile);
    if (profile.id == ref.read(currentProfileIdProvider)) {
      ref.read(setupActionProvider.notifier).applyProfileDebounce();
    }
  }

  Future<void> addProfileFormQrCode() async {
    final url = await globalState.safeRun(picker.pickerConfigQRCode);
    if (url == null) return;
    addProfileFormURL(url);
  }

  void reorder(List<Profile> profiles) {
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  Future<void> clearEffect(int profileId) async {
    final profilePath = await appPath.getProfilePath(profileId.toString());
    final providersDirPath = await appPath.getProvidersDirPath(
      profileId.toString(),
    );
    final profileFile = File(profilePath);
    final isExists = await profileFile.exists();
    if (isExists) {
      await profileFile.safeDelete(recursive: true);
    }
    await coreController.deleteFile(providersDirPath);
  }
}
