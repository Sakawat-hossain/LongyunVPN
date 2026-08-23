import 'dart:io';

import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LongyunHttpOverrides extends HttpOverrides {
  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return 'DIRECT';
    }
    final ref = globalState.rootRef;
    final isStart = ref.read(isStartProvider);
    final suspend = ref.read(suspendProvider);
    // Deliberately don't log the request URL here: findProxy runs for every
    // request, so logging $url would record the user's browsing/API targets.
    if (!isStart || suspend) return 'DIRECT';
    final mixedPort = ref.read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return 'PROXY localhost:$mixedPort';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Never blanket-accept invalid certificates. This client also serves the
    // app's own API/auth traffic (which is tunnelled through the local proxy),
    // so accepting any cert would expose that traffic — including the Xboard
    // token — to MITM. TLS validates end-to-end through the proxy, so real
    // endpoints must present a valid chain. Only the loopback proxy control
    // socket is trusted, and it speaks plaintext HTTP so this never fires for
    // it anyway; the guard is a defensive no-op, not a bypass.
    client.badCertificateCallback = (cert, host, port) =>
        host == localhost || host == 'localhost' || host == '::1';
    client.findProxy = handleFindProxy;
    return client;
  }
}
