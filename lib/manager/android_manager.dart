import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/core/core.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/plugins/app.dart';
import 'package:longyunvpn/plugins/service.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ApplicationExitInfo.REASON_* values, so the log names a cause instead of a
/// bare number.
const _exitReasonNames = <int, String>{
  0: 'UNKNOWN',
  1: 'EXIT_SELF',
  2: 'SIGNALED',
  3: 'LOW_MEMORY',
  4: 'CRASH',
  5: 'CRASH_NATIVE',
  6: 'ANR',
  7: 'INITIALIZATION_FAILURE',
  8: 'PERMISSION_CHANGE',
  9: 'EXCESSIVE_RESOURCE_USAGE',
  10: 'USER_REQUESTED',
  11: 'USER_STOPPED',
  12: 'DEPENDENCY_DIED',
  13: 'OTHER',
  14: 'FREEZER',
  15: 'PACKAGE_STATE_CHANGE',
  16: 'PACKAGE_UPDATED',
};

/// Exits worth flagging: the process was killed or failed, as opposed to
/// closing normally or being stopped by the user. SIGNALED is the one OEM task
/// killers usually leave behind.
const _abnormalExitReasons = {2, 3, 4, 5, 6, 7, 9, 12};

class AndroidManager extends ConsumerStatefulWidget {
  final Widget child;

  const AndroidManager({super.key, required this.child});

  @override
  ConsumerState<AndroidManager> createState() => _AndroidContainerState();
}

class _AndroidContainerState extends ConsumerState<AndroidManager>
    with ServiceListener {
  @override
  void initState() {
    super.initState();
    ref.listenManual(appSettingProvider.select((state) => state.hidden), (
      prev,
      next,
    ) {
      app?.updateExcludeFromRecents(next);
    }, fireImmediately: true);
    ref.listenManual(sharedStateProvider, (prev, next) {
      if (prev != next) {
        debouncer.call(FunctionTag.saveSharedFile, () async {
          preferences.saveShareState(next);
        }, duration: const Duration(seconds: 1));
        if (prev?.needSyncSharedState != next.needSyncSharedState) {
          service?.syncState(next.needSyncSharedState);
        }
      }
    });
    service?.addListener(this);
    unawaited(_logLastExit());
  }

  /// Logs why Android ended this app's process the previous time it ran.
  ///
  /// The system keeps that record itself, and it is the only account of a
  /// phone that "just stopped" connecting: when the process is killed, the app
  /// is not running to write anything down. Reading it once at startup puts it
  /// in the in-app log, where someone without adb can actually find it.
  Future<void> _logLastExit() async {
    try {
      final info = await app?.getLastExitInfo();
      if (info == null) return;
      final reason = info['reason'];
      final name = reason is int ? _exitReasonNames[reason] : null;
      final timestamp = info['timestamp'];
      final at = timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp).toString()
          : 'an unknown time';
      final description = info['description'];
      final detail = description is String && description.isNotEmpty
          ? ' - $description'
          : '';
      commonPrint.log(
        'Previous exit: ${name ?? 'reason $reason'} at $at$detail',
        logLevel: _abnormalExitReasons.contains(reason)
            ? LogLevel.warning
            : LogLevel.info,
      );
    } catch (e) {
      commonPrint.log(
        'Previous exit: unavailable ($e)',
        logLevel: LogLevel.warning,
      );
    }
  }

  @override
  Future<void> dispose() async {
    service?.removeListener(this);
    super.dispose();
  }

  @override
  void onServiceEvent(CoreEvent event) {
    coreEventManager.sendEvent(event);
    super.onServiceEvent(event);
  }

  @override
  void onServiceCrash(String message) {
    coreEventManager.sendEvent(
      CoreEvent(type: CoreEventType.crash, data: message),
    );
    super.onServiceCrash(message);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
