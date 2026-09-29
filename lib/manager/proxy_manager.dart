import 'package:longyunvpn/common/proxy.dart';
import 'package:longyunvpn/common/print.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<void> _pendingUpdate = Future.value();

  Future<void> _updateProxy(ProxyState proxyState) async {
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    bool? result;
    if (isStart && systemProxy) {
      result = await proxy?.startProxy(port, proxyState.bassDomain);
    } else {
      // The port lets Windows recognise a proxy of ours even without the
      // record it now keeps - one left by an older version, say - while still
      // leaving anybody else's proxy alone.
      result = await proxy?.stopProxy(port);
    }
    if (result == false) {
      commonPrint.log('update system proxy failed', logLevel: LogLevel.warning);
    }
  }

  void _scheduleUpdateProxy(ProxyState proxyState) {
    _pendingUpdate = _pendingUpdate
        .then((_) => _updateProxy(proxyState))
        .catchError((Object error) {
          commonPrint.log(
            'update system proxy failed: $error',
            logLevel: LogLevel.warning,
          );
        });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _scheduleUpdateProxy(next);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
