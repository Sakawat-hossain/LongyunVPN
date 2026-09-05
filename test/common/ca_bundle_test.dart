import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The bundle exists to rescue machines whose OS trust store is incomplete — a
/// Windows install with root auto-update disabled, where every HTTPS call fails
/// with CERTIFICATE_VERIFY_FAILED while the browser beside it works.
///
/// A bundle that is missing, truncated or unparseable would put those machines
/// straight back where they were, and the symptom appears only on the affected
/// machine, which is nobody's development machine. So assert here that the file
/// ships, that it parses, and that BoringSSL — the thing that actually has to
/// read it at runtime — accepts it.
void main() {
  final file = File('assets/data/ca_bundle.pem');

  test('the bundle ships with the app', () {
    expect(
      file.existsSync(),
      isTrue,
      reason: 'assets/data/ca_bundle.pem is missing; desktop builds would fall '
          'back to the OS trust store alone',
    );
  });

  test('it carries a full root store, not a stub', () {
    final certs = 'BEGIN CERTIFICATE'.allMatches(file.readAsStringSync()).length;
    // Mozilla's store has held well over a hundred roots for years. A file with
    // a handful is a truncated download or a placeholder, not a trust store.
    expect(
      certs,
      greaterThan(100),
      reason: 'only $certs certificates found',
    );
  });

  test('BoringSSL parses it, so install() will not be a no-op at runtime', () {
    // setTrustedCertificatesBytes is what CaBundle.install calls. If the file
    // is malformed this throws here rather than on a user's machine.
    final context = SecurityContext(withTrustedRoots: false);
    expect(
      () => context.setTrustedCertificatesBytes(file.readAsBytesSync()),
      returnsNormally,
    );
  });

  test('it can validate the panel host on its own', () {
    // Not a network call: this pins the roots the account API's chain
    // terminates at. The chain served by admin.jsssbd.com is
    //   jsssbd.com -> GTS WE1 -> GTS Root R4 -> GlobalSign Root CA
    // so losing either of those from the bundle would silently reintroduce the
    // exact failure it was added to fix.
    final text = file.readAsStringSync();
    expect(text, contains('GlobalSign Root CA'));
    expect(text, contains('GTS Root R4'));
  });
}
