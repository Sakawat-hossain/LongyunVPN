import 'dart:async';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/core.dart';
import 'package:longyunvpn/plugins/service.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';

import 'interface.dart';

class CoreLib extends CoreHandlerInterface {
  static CoreLib? _instance;

  Completer<bool> _connectedCompleter = Completer();

  CoreLib._internal();

  @override
  Future<String> preload() async {
    if (_connectedCompleter.isCompleted) {
      // Already connected, which is success. This used to return the string
      // 'core is connected', but the contract here is that an empty string
      // means success and anything else is an error message — so connectCore
      // read it as a failure, set the status to disconnected on a core that was
      // working, and popped 'core is connected' up as if it were an error.
      // From there every call went to a core the app believed was dead: proxy
      // groups came back empty and the Servers page showed "No Nodes
      // Available". The desktop implementation returns '' here, which is why
      // this only ever bit Android.
      return '';
    }
    final res = await service?.init();
    // An empty string means success. Anything else — including null, which is
    // what a missing/unbound service channel yields — is a failure. The old
    // condition returned `res ?? ''` for null, i.e. an EMPTY string, which every
    // caller reads as success: connectCore then flipped the status to
    // "connected" while the completer was never completed and the core was
    // never actually initialised. Every later call then timed out silently and
    // the proxy groups stayed empty, so the Servers page showed nothing with no
    // error anywhere.
    if (res == null) {
      const message = 'core service unavailable';
      commonPrint.log('preload failed: $message', logLevel: LogLevel.error);
      return message;
    }
    if (res.isNotEmpty) {
      commonPrint.log('preload failed: $res', logLevel: LogLevel.error);
      return res;
    }
    _connectedCompleter.complete(true);
    final syncRes = await service?.syncState(
      globalState.rootRef.read(sharedStateProvider),
    );
    return syncRes ?? '';
  }

  factory CoreLib() {
    _instance ??= CoreLib._internal();
    return _instance!;
  }

  @override
  FutureOr<bool> destroy() async {
    return true;
  }

  @override
  Future<bool> shutdown(_) async {
    if (!_connectedCompleter.isCompleted) {
      return false;
    }
    _connectedCompleter = Completer();
    return service?.shutdown() ?? true;
  }

  @override
  Future<bool> startListener() async {
    await super.startListener();
    await service?.start();
    return true;
  }

  @override
  Future<bool> stopListener() async {
    await super.stopListener();
    await service?.stop();
    return true;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    // A null here means the call to the Android service timed out or the
    // service isn't bound. That used to be swallowed silently, so a failed
    // setupConfig/getProxies looked identical to "there are simply no proxies"
    // — the Servers page stayed empty and nothing was logged. Keep returning
    // null (callers handle it) but make the failure visible.
    if (service == null) {
      commonPrint.log(
        'core invoke ${method.name}: service unavailable',
        logLevel: LogLevel.error,
      );
      return null;
    }
    // The timeout argument used to be accepted and then dropped, so every call
    // fell back to withTimeout's three-minute default. Adding a subscription
    // goes through here (validateConfig) behind a modal spinner, so a core that
    // was slow to answer looked exactly like a profile that never loads — three
    // minutes is indistinguishable from forever to someone watching it. Honour
    // the caller's value, and default to something a person will actually wait
    // through.
    final result = await service
        ?.invokeAction(Action(id: id, method: method, data: data))
        .withTimeout(
          timeout: timeout ?? const Duration(seconds: 60),
          onTimeout: () => null,
        );
    if (result == null) {
      commonPrint.log(
        'core invoke ${method.name}: no result (timed out)',
        logLevel: LogLevel.error,
      );
      return null;
    }
    return parasResult<T>(result);
  }

  @override
  Completer get completer => _connectedCompleter;
}

CoreLib? get coreLib => system.isAndroid ? CoreLib() : null;
