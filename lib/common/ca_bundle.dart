import 'dart:io';

import 'package:flutter/services.dart';

import 'print.dart';
import 'package:longyunvpn/enum/enum.dart';

/// Adds a bundled set of root certificates to the default TLS trust store.
///
/// Dart validates certificates through BoringSSL against the roots the OS has
/// **already cached**. Windows, though, fetches roots from Windows Update on
/// demand the first time one is needed — and Edge and Chrome trigger that
/// fetch while Dart does not. On a machine where root auto-update is disabled
/// (LTSC images, debloated installs, locked-down policy) the root is simply
/// never there, and every HTTPS call from the app dies with:
///
///   CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate
///
/// while the same URL opens fine in the browser next to it. That was reported
/// as "Unknown network error" when adding a profile, on one laptop, on a
/// network where every other device worked.
///
/// The server was not at fault: it serves a complete chain. The machine simply
/// could not see the root it terminates at.
///
/// [setTrustedCertificatesBytes] *adds* to the default trust store rather than
/// replacing it, so a healthy machine is unaffected and a machine missing a
/// root gets it. The cost is that these roots are ours to update: one revoked
/// upstream stays trusted here until the next release.
///
/// Desktop only. Android and macOS/iOS ship complete, self-maintaining trust
/// stores, so there is nothing to add and no reason to widen the surface.
abstract final class CaBundle {
  static const _asset = 'assets/data/ca_bundle.pem';

  /// Loaded once at startup, before anything makes an HTTPS request.
  ///
  /// Never throws. A missing or unreadable bundle leaves the OS trust store
  /// exactly as it was — which is the behaviour every release before this one
  /// had, so the worst case is no worse than the status quo.
  static Future<void> install() async {
    if (!Platform.isWindows && !Platform.isLinux) {
      return;
    }
    try {
      final data = await rootBundle.load(_asset);
      SecurityContext.defaultContext.setTrustedCertificatesBytes(
        data.buffer.asUint8List(),
      );
      commonPrint.log('CA bundle installed (${data.lengthInBytes} bytes)');
    } on TlsException catch (e) {
      // Thrown when a certificate in the bundle is already trusted or cannot be
      // parsed. Neither is fatal: the roots that did load are in place, and the
      // OS store is still behind them.
      commonPrint.log(
        'CA bundle partially applied: ${e.message}',
        logLevel: LogLevel.warning,
      );
    } catch (e) {
      commonPrint.log(
        'CA bundle not installed: $e',
        logLevel: LogLevel.warning,
      );
    }
  }
}
