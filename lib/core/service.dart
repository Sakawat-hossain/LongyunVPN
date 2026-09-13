import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/core/core.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/core.dart';

import 'interface.dart';
import 'transport.dart';

class CoreService extends CoreHandlerInterface {
  static CoreService? _instance;

  late final IPCCoreTransport _transport;

  Completer<bool> _shutdownCompleter = Completer();

  final Map<String, Completer> _callbackCompleterMap = {};

  Process? _process;

  factory CoreService() {
    _instance ??= CoreService._internal();
    return _instance!;
  }

  CoreService._internal() {
    _transport = IPCCoreTransport(
      address: system.isWindows ? windowsPipeName : unixSocketPath,
    );
    _initServer();
  }

  Future<void> handleResult(ActionResult result) async {
    final completer = _callbackCompleterMap[result.id];
    final data = await parasResult(result);
    if (result.id?.isEmpty == true) {
      coreEventManager.sendEvent(CoreEvent.fromJson(result.data));
    }
    if (completer?.isCompleted == true) {
      return;
    }
    completer?.complete(data);
  }

  Future<void> _initServer() async {
    await _transport.init();

    _transport.onDisconnect = () {
      _handleInvokeCrashEvent();
      if (!_shutdownCompleter.isCompleted) {
        _shutdownCompleter.complete(true);
      }
    };

    _transport.dataStream
        .transform(uint8ListToListIntConverter)
        .transform(utf8.decoder)
        .listen(
          (data) async {
            try {
              final dataJson = await data.trim().commonToJSON<dynamic>();
              handleResult(ActionResult.fromJson(dataJson));
            } catch (e) {
              commonPrint.log(
                'Failed to parse transport data: $e',
                logLevel: LogLevel.error,
              );
            }
          },
          onError: (error) {
            commonPrint.log(
              'Transport data stream error: $error',
              logLevel: LogLevel.error,
            );
          },
        );
  }

  void _handleInvokeCrashEvent() {
    coreEventManager.sendEvent(
      const CoreEvent(type: CoreEventType.crash, data: 'core done'),
    );
  }

  /// How long to wait for a started core to dial back in over the transport.
  /// Bounded so a core that launches but never connects fails with a reason
  /// rather than leaving preload awaiting a completer forever.
  static const _connectTimeout = Duration(seconds: 15);

  /// Starts the core process and waits for it to connect.
  ///
  /// Returns an empty string on success and a human-readable reason on failure,
  /// which is the contract [preload] and `connectCore` already work to.
  Future<String> start() async {
    if (_process != null) {
      await shutdown(false);
    }
    if (system.isWindows && await system.checkIsAdmin()) {
      final isSuccess = await request.startCoreByHelper(_transport.address);
      if (isSuccess) {
        return _awaitConnection();
      }
    }
    try {
      _process = await Process.start(appPath.corePath, [_transport.address]);
    } catch (e) {
      // Reported now, not only logged. This used to return normally and preload
      // answered '' regardless — which every caller reads as success — so a core
      // that never started left the app displaying "connected" over nothing:
      // every later call timed out, the proxy list came back empty, and the
      // Servers page said "No Nodes Available" with no error anywhere to explain
      // it. The desktop path had the same hole that was already closed for
      // Android in CoreLib.preload.
      final message = 'core process failed to start: $e';
      commonPrint.log(message, logLevel: LogLevel.error);
      _handleInvokeCrashEvent();
      return message;
    }
    final process = _process!;
    process.stdout.listen((_) {});
    process.stderr.listen((e) {
      final error = utf8.decode(e);
      if (error.isNotEmpty) {
        commonPrint.log(error, logLevel: LogLevel.warning);
      }
    });
    // Why the core went away is otherwise unrecoverable, and it is the one fact
    // that separates three very different problems that all look identical from
    // the UI (an empty server list): the core crashing, the core exiting
    // cleanly, and the OS killing it — a macOS code-signing or quarantine
    // refusal shows up here as a SIGKILL. shutdown() clears _process before the
    // exit code lands, so a deliberate stop stays quiet and only an unexpected
    // death is reported.
    unawaited(
      process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        commonPrint.log(
          'core process ended unexpectedly with exit code $code',
          logLevel: LogLevel.error,
        );
      }),
    );
    return _awaitConnection();
  }

  /// Waits for the core to connect back, bounded by [_connectTimeout]. A core
  /// that spawns but is killed before it can dial in — a signed-binary or
  /// quarantine refusal on macOS looks exactly like this — is a failure, not
  /// something to wait on indefinitely.
  Future<String> _awaitConnection() async {
    try {
      await _transport.connectionCompleter.future.timeout(_connectTimeout);
      return '';
    } on TimeoutException {
      const message = 'core started but never connected';
      commonPrint.log(message, logLevel: LogLevel.error);
      _handleInvokeCrashEvent();
      return message;
    }
  }

  @override
  FutureOr<bool> destroy() async {
    await shutdown(false);
    await _transport.close();
    return true;
  }

  Future<void> sendMessage(String message) async {
    await _transport.connectionCompleter.future;
    _transport.send(message);
  }

  @override
  Future<bool> shutdown(bool isUser) async {
    _shutdownCompleter = Completer();
    if (system.isWindows) {
      await request.stopCoreByHelper();
    }
    _transport.disconnected();
    _process?.kill();
    _process = null;
    _clearCompleter();
    if (isUser) {
      return _shutdownCompleter.future;
    } else {
      return true;
    }
  }

  void _clearCompleter() {
    for (final completer in _callbackCompleterMap.values) {
      completer.safeCompleter(null);
    }
  }

  @override
  Future<String> preload() async {
    return start();
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    _callbackCompleterMap[id] = Completer<T?>();
    sendMessage(json.encode(Action(id: id, method: method, data: data)));
    return (_callbackCompleterMap[id] as Completer<T?>).future.withTimeout(
      timeout: timeout,
      onLast: () {
        final completer = _callbackCompleterMap[id];
        completer?.safeCompleter(null);
        _callbackCompleterMap.remove(id);
      },
      tag: id,
      onTimeout: () => null,
    );
  }

  @override
  Completer get completer => _transport.connectionCompleter;
}

final coreService = system.isDesktop ? CoreService() : null;
