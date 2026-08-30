import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/request.dart';

/// "Unknown network error" was every failure's answer: a certificate that would
/// not verify, a hostname that would not resolve and a refused socket all
/// arrived at the user as the same four words. These assert the cause survives
/// as far as the dialog, since that string is the only thing a user can report
/// and often the only thing a maintainer gets.
void main() {
  group('describeNetworkError', () {
    test('names a TLS failure and keeps the reason from the OS', () {
      const error = HandshakeException(
        'Handshake error in client',
        OSError('CERTIFICATE_VERIFY_FAILED: self signed certificate'),
      );
      final described = Request.describeNetworkError(error);
      expect(described, contains('TLS'));
      expect(described, contains('CERTIFICATE_VERIFY_FAILED'));
    });

    test('falls back to the exception message when there is no OS error', () {
      final described = Request.describeNetworkError(
        const HandshakeException('Handshake error in client'),
      );
      expect(described, contains('Handshake error in client'));
    });

    test('reports the host that could not be reached', () {
      final error = SocketException(
        'Failed host lookup',
        osError: const OSError('No such host is known'),
        address: InternetAddress('127.0.0.1'),
      );
      final described = Request.describeNetworkError(error);
      expect(described, contains('No such host is known'));
      expect(described, contains('127.0.0.1'));
    });

    test('handles a socket error carrying no address', () {
      final described = Request.describeNetworkError(
        const SocketException('Connection refused'),
      );
      expect(described, contains('Connection refused'));
      expect(described, isNot(contains('(')));
    });

    test('says so plainly when there is nothing to describe', () {
      expect(Request.describeNetworkError(null), 'no further detail');
    });

    test('calls a parse failure what it is', () {
      expect(
        Request.describeNetworkError(const FormatException('bad')),
        'malformed response',
      );
    });

    test('truncates a long error so the dialog stays readable', () {
      final described = Request.describeNetworkError('x' * 500);
      expect(described.length, lessThanOrEqualTo(161));
      expect(described, endsWith('…'));
    });

    test('leaves a short unrecognised error intact', () {
      expect(Request.describeNetworkError('boom'), 'boom');
    });
  });
}
