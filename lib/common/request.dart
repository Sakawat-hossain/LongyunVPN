import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
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
  }

  /// Exposed so a test can assert these clients are actually bounded; an
  /// unbounded one is invisible until a request stalls in front of a user.
  @visibleForTesting
  BaseOptions get clashDioOptions => _clashDio.options;

  @visibleForTesting
  BaseOptions get dioOptions => dio.options;

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      commonPrint.log('getFileResponseForUrl error ${e.toString()}');
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
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
        rethrow;
      }
      throw currentAppLocalizations.unknownNetworkError;
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
