import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/request.dart';

/// A customer could not add a subscription. The same link worked in Clash Verge
/// on the same machine, on the same network.
///
/// The difference: Clash Verge downloads subscriptions directly by default, and
/// this app sends the download through its own core whenever the VPN is on. The
/// customer's core was running with no working node - the old subscription's -
/// so it accepted the connection and hung up before answering:
///
///   DioException [connection error]
///   Error: HttpException: Connection closed before full header was received
///
/// There was already a direct retry for exactly this situation, but it only
/// recognised a *refused* socket (a core not listening yet). A core that is
/// listening and cannot carry the request surfaces as an HttpException instead,
/// and was never retried. These pin both shapes.
void main() {
  RequestOptions request() =>
      RequestOptions(path: 'https://sub01.longyunvpn.com/baidu/token');

  DioException failure(DioExceptionType type, [Object? error]) =>
      DioException(requestOptions: request(), type: type, error: error);

  group('shouldRetryDirect, when the download went through our core', () {
    test('retries the failure the customer actually hit', () {
      final e = failure(
        DioExceptionType.connectionError,
        const HttpException(
          'Connection closed before full header was received',
        ),
      );
      expect(Request.shouldRetryDirect(e, wasProxied: true), isTrue);
    });

    test('still retries a refused socket, which it always did', () {
      final e = failure(
        DioExceptionType.connectionError,
        const SocketException(
          'Connection refused',
          address: null,
          port: 7890,
        ),
      );
      expect(Request.shouldRetryDirect(e, wasProxied: true), isTrue);
    });

    test('retries a proxy that stalls rather than failing', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.unknown,
      ]) {
        expect(
          Request.shouldRetryDirect(failure(type), wasProxied: true),
          isTrue,
          reason: '$type through the core should be retried direct',
        );
      }
    });

    test('does not retry when the server answered', () {
      // A 403 for an invalid token is a real answer. Asking again by another
      // route would get the same answer and hide it behind a second failure.
      for (final type in [
        DioExceptionType.badResponse,
        DioExceptionType.badCertificate,
        DioExceptionType.cancel,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          Request.shouldRetryDirect(failure(type), wasProxied: true),
          isFalse,
          reason: '$type is not a routing problem',
        );
      }
    });
  });

  test('never retries a download that was already direct', () {
    // Nothing to route around: retrying direct would repeat the same request
    // and report the same failure twice as slowly.
    final e = failure(
      DioExceptionType.connectionError,
      const HttpException('Connection closed before full header was received'),
    );
    expect(Request.shouldRetryDirect(e, wasProxied: false), isFalse);
  });

  test('describes the hang-up in words a customer can read', () {
    expect(
      Request.describeNetworkError(
        const HttpException(
          'Connection closed before full header was received',
        ),
      ),
      'the server closed the connection before answering',
    );
  });
}
