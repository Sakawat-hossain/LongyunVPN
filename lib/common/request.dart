import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/models/models.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;

  /// Same settings as [_clashDio] but never routed through the local proxy.
  /// Used only as a fallback when that proxy refuses the connection.
  late final Dio _directDio;
  String? userAgent;

  // Dio defaults every timeout to null, which means "wait forever". That is
  // what made adding a subscription hang: the fetch sat behind a modal spinner
  // with no timeout, no error and no way out whenever the connection stalled
  // rather than failing outright — common on mobile networks, and on any
  // request routed through the local proxy before the core is serving.
  // Generous enough for a large subscription over slow mobile data, but
  // bounded so a stall always becomes a visible error.
  static const _connectTimeout = Duration(seconds: 15);
  static const _receiveTimeout = Duration(seconds: 60);
  static const _sendTimeout = Duration(seconds: 30);

  Request() {
    dio = Dio(
      BaseOptions(
        headers: {'User-Agent': browserUa},
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
      ),
    );
    // downloadFile passes its own longer per-request timeouts, which override
    // these, so large installer downloads are unaffected.
    _clashDio = Dio(
      BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
      ),
    );
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return LongyunHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
    _directDio = Dio(
      BaseOptions(
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
      ),
    );
    _directDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) {
          client.userAgent = globalState.ua;
          return 'DIRECT';
        };
        return client;
      },
    );
  }

  /// A short, readable cause for a network failure.
  ///
  /// DioExceptionType.unknown is a wrapper, not a diagnosis: the actual reason
  /// — a TLS handshake that failed, a name that did not resolve, a socket the
  /// machine refused — sits in [error]. Reporting only "Unknown network error"
  /// discarded it, which left the person looking at a dialog naming no cause
  /// and nothing to act on. A Windows machine that cannot add a profile on a
  /// network where every other device can is exactly the case that hid: the
  /// answer was in the exception the whole time.
  ///
  /// Kept short, and appended to the localized message rather than replacing
  /// it, so the dialog stays readable. The detail is OS text and stays in
  /// English — untranslated but specific beats translated and useless.
  static String describeNetworkError(Object? error) {
    if (error is HandshakeException) {
      final detail = error.osError?.message ?? error.message;
      return detail.isEmpty ? 'TLS handshake failed' : 'TLS: $detail';
    }
    if (error is SocketException) {
      final host = error.address?.host;
      final detail = error.osError?.message ?? error.message;
      final where = host == null || host.isEmpty ? '' : ' ($host)';
      return detail.isEmpty ? 'no connection$where' : '$detail$where';
    }
    if (error is FormatException) {
      return 'malformed response';
    }
    if (error == null) {
      return 'no further detail';
    }
    final text = error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  /// True when the failure is the local proxy refusing the connection, rather
  /// than the remote host being unreachable. Only that case is worth retrying
  /// direct — a genuinely offline device should still report being offline.
  static bool isLocalProxyRefused(DioException e) => _isLocalProxyRefused(e);

  static bool _isLocalProxyRefused(DioException e) {
    if (e.type != DioExceptionType.connectionError) return false;
    final error = e.error;
    if (error is! SocketException) return false;
    final host = error.address?.host ?? '';
    return host == localhost || host == '127.0.0.1' || host == '::1';
  }

  /// Exposed so a test can assert these clients are actually bounded; an
  /// unbounded one is invisible until a request stalls in front of a user.
  @visibleForTesting
  BaseOptions get clashDioOptions => _clashDio.options;

  @visibleForTesting
  BaseOptions get dioOptions => dio.options;

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    final options = Options(responseType: ResponseType.bytes);
    try {
      return await _clashDio.get<Uint8List>(url, options: options);
    } catch (error) {
      // Once the app considers itself started, every request here is sent to
      // localhost:<mixedPort>. The core is not always listening on it yet — no
      // config loaded, or the listener still coming up — and the socket is then
      // refused outright. That is fatal at exactly the wrong moment: fetching
      // the very first subscription, which is what has to succeed before the
      // core has anything to serve. Retry without the proxy rather than fail
      // the import; the happy path is untouched, and a device that is simply
      // offline still reports being offline because the retry fails too.
      var e = error;
      if (e is DioException && _isLocalProxyRefused(e)) {
        commonPrint.log(
          'subscription fetch refused by local proxy, retrying direct',
          logLevel: LogLevel.warning,
        );
        try {
          return await _directDio.get<Uint8List>(url, options: options);
        } catch (retryError) {
          e = retryError;
        }
      }
      commonPrint.log('getFileResponseForUrl error ${e.toString()}');
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw '${currentAppLocalizations.unknownNetworkError}\n'
              '${describeNetworkError(e.error)}';
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          // Reachable only now that timeouts are set; rethrowing the raw
          // DioException here would put a stack-trace-ish string in front of
          // the user instead of something they can act on.
          throw currentAppLocalizations.timeout;
        }
        throw e;
      }
      // Not a DioException at all — describe whatever it is rather than
      // reporting the same bare "unknown" for every possible cause.
      throw '${currentAppLocalizations.unknownNetworkError}\n'
          '${describeNetworkError(e)}';
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response;
  }

  /// Downloads [url] to [savePath] (used for the in-app installer update).
  ///
  /// Returns true on success. Never throws: large GitHub release downloads can
  /// stall (especially on restricted networks), so this retries a few times
  /// with a generous receive timeout, cleans up partial files, and reports
  /// failure via the bool so the caller can fall back to opening the browser
  /// instead of surfacing a raw socket error to the user.
  Future<bool> downloadFile(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    int retries = 3,
  }) async {
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        await dio.download(
          url,
          savePath,
          onReceiveProgress: onProgress,
          cancelToken: cancelToken,
          deleteOnError: true,
          options: Options(
            headers: {'User-Agent': browserUa},
            followRedirects: true,
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 15),
          ),
        );
        return true;
      } catch (e) {
        // A cancellation is a deliberate user action, not a transport failure —
        // retrying it would ignore the user and download the file anyway.
        final cancelled = e is DioException &&
            e.type == DioExceptionType.cancel;
        commonPrint.log(
          cancelled
              ? 'downloadFile cancelled'
              : 'downloadFile attempt $attempt/$retries failed: $e',
          logLevel: LogLevel.warning,
        );
        try {
          final file = File(savePath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
        if (cancelled) return false;
        if (attempt < retries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await dio.get(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) return null;
      final data = response.data as Map<String, dynamic>;
      // Guard against a malformed/empty tag: calling replaceAll on a null (or
      // non-String) tag_name used to throw and get swallowed as "no update".
      final remoteVersion = data['tag_name'];
      if (remoteVersion is! String || remoteVersion.isEmpty) return null;
      final version = globalState.packageInfo.version;
      final hasUpdate =
          utils.compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
      if (!hasUpdate) return null;
      return data;
    } catch (e) {
      commonPrint.log('checkForUpdate failed', logLevel: LogLevel.warning);
      return null;
    }
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
        source.key,
        cancelToken: token,
        options: Options(responseType: ResponseType.json),
      )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
        if (res.statusCode == HttpStatus.ok && res.data != null) {
          completer.complete(Result.success(source.value(res.data!)));
          return;
        }
        commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
        failureCount++;
        handleFailRes();
      })
          .catchError((e) {
        failureCount++;
        if (e is DioException && e.type == DioExceptionType.cancel) {
          completer.complete(Result.error('cancelled'));
          return;
        }
        commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
        handleFailRes();
      });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }

  /// The privileged helper authenticates every request against the core SHA256
  /// (embedded in the app at build time as `CORE_SHA256`). Sending it as the
  /// Authorization header is what lets a legitimate local call through while a
  /// cross-origin browser request — which can't set this header without a CORS
  /// preflight the helper never approves — is rejected.
  Options _helperOptions() => Options(
        responseType: ResponseType.plain,
        headers: {'Authorization': globalState.coreSHA256},
      );

  Future<bool> pingHelper() async {
    if (kDebugMode) return true;
    try {
      final response = await dio
          .get(
        'http://$localhost:$helperPort/ping',
        options: _helperOptions(),
      )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      // The helper replies "ok" once it has accepted our token.
      return (response.data as String).trim() == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final response = await dio
          .post(
        'http://$localhost:$helperPort/start',
        data: json.encode({'path': appPath.corePath, 'arg': arg}),
        options: _helperOptions(),
      )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await dio
          .post(
        'http://$localhost:$helperPort/stop',
        options: _helperOptions(),
      )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }
}

final request = Request();
