import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'constant.dart';

class XboardApiException implements Exception {
  final String message;

  XboardApiException(this.message);

  @override
  String toString() => message;
}

class XboardUserInfo {
  final String email;
  final num balance;
  final num transferEnable;
  final int? expiredAt;
  final int? planId;

  XboardUserInfo({
    required this.email,
    required this.balance,
    required this.transferEnable,
    this.expiredAt,
    this.planId,
  });

  factory XboardUserInfo.fromJson(Map<String, dynamic> json) {
    return XboardUserInfo(
      email: json['email'] as String? ?? '',
      balance: json['balance'] as num? ?? 0,
      transferEnable: json['transfer_enable'] as num? ?? 0,
      expiredAt: json['expired_at'] as int?,
      planId: json['plan_id'] as int?,
    );
  }
}

class XboardSubscribeInfo {
  final String subscribeUrl;
  final num? u;
  final num? d;
  final num? transferEnable;
  final int? expiredAt;
  final Map<String, dynamic>? plan;

  XboardSubscribeInfo({
    required this.subscribeUrl,
    this.u,
    this.d,
    this.transferEnable,
    this.expiredAt,
    this.plan,
  });

  factory XboardSubscribeInfo.fromJson(Map<String, dynamic> json) {
    return XboardSubscribeInfo(
      subscribeUrl: json['subscribe_url'] as String? ?? '',
      u: json['u'] as num?,
      d: json['d'] as num?,
      transferEnable: json['transfer_enable'] as num?,
      expiredAt: json['expired_at'] as int?,
      plan: json['plan'] as Map<String, dynamic>?,
    );
  }
}

/// A single feature row inside a plan's `content` (which the panel returns as
/// a JSON *string*, not an object — so it must be decoded separately).
class XboardPlanFeature {
  final String feature;
  final bool support;

  XboardPlanFeature({required this.feature, required this.support});

  factory XboardPlanFeature.fromJson(Map<String, dynamic> json) {
    return XboardPlanFeature(
      feature: json['feature'] as String? ?? '',
      support: json['support'] as bool? ?? true,
    );
  }
}

/// The ordered set of purchasable period keys, matching the V2Board/Xboard
/// `*_price` columns. The key is exactly what `/user/order/save` expects in its
/// `period` field.
/// The `period` value that orders a traffic reset for the current plan.
const xboardResetPeriod = 'reset_price';

const xboardPeriods = <String, String>{
  'month_price': 'Monthly',
  'quarter_price': 'Quarterly',
  'half_year_price': 'Half-yearly',
  'year_price': 'Yearly',
  'two_year_price': '2 Years',
  'three_year_price': '3 Years',
  'onetime_price': 'One-time',
};

class XboardPlan {
  final int id;
  final String name;
  final List<String> tags;
  final List<XboardPlanFeature> features;

  /// Available period -> price in cents (分). Only non-null prices are kept.
  final Map<String, int> periodPrices;
  final num? transferEnable;
  final num? speedLimit;
  final int? deviceLimit;
  final bool sell;

  /// Price in cents (分) to reset/top-up traffic mid-cycle without renewing the
  /// whole plan. Null when the plan doesn't offer a reset. Ordered with
  /// `period: 'reset_price'` against the user's current plan id.
  final int? resetPrice;

  XboardPlan({
    required this.id,
    required this.name,
    required this.tags,
    required this.features,
    required this.periodPrices,
    this.transferEnable,
    this.speedLimit,
    this.deviceLimit,
    this.sell = true,
    this.resetPrice,
  });

  factory XboardPlan.fromJson(Map<String, dynamic> json) {
    final periodPrices = <String, int>{};
    for (final key in xboardPeriods.keys) {
      final value = json[key];
      if (value is num) {
        periodPrices[key] = value.toInt();
      }
    }
    var features = <XboardPlanFeature>[];
    final content = json['content'];
    if (content is String && content.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is List) {
          features = decoded
              .whereType<Map<String, dynamic>>()
              .map(XboardPlanFeature.fromJson)
              .toList();
        }
      } catch (_) {
        // Malformed content — show the plan without feature rows rather than
        // failing the whole list.
      }
    }
    return XboardPlan(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      features: features,
      periodPrices: periodPrices,
      transferEnable: json['transfer_enable'] as num?,
      speedLimit: json['speed_limit'] as num?,
      deviceLimit: json['device_limit'] as int?,
      sell: (json['sell'] as bool?) ?? true,
      resetPrice: (json['reset_price'] as num?)?.toInt(),
    );
  }
}

class XboardPaymentMethod {
  final int id;
  final String name;
  final String? icon;

  XboardPaymentMethod({required this.id, required this.name, this.icon});

  factory XboardPaymentMethod.fromJson(Map<String, dynamic> json) {
    return XboardPaymentMethod(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}

class XboardCommConfig {
  final bool isEmailVerify;
  final bool isInviteForce;
  final List<String> emailWhitelistSuffix;
  final bool isCaptcha;

  XboardCommConfig({
    required this.isEmailVerify,
    required this.isInviteForce,
    required this.emailWhitelistSuffix,
    required this.isCaptcha,
  });

  factory XboardCommConfig.fromJson(Map<String, dynamic> json) {
    return XboardCommConfig(
      isEmailVerify: (json['is_email_verify'] as num? ?? 0) != 0,
      isInviteForce: (json['is_invite_force'] as num? ?? 0) != 0,
      emailWhitelistSuffix:
          (json['email_whitelist_suffix'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isCaptcha: (json['is_captcha'] as num? ?? 0) != 0,
    );
  }
}

class XboardApi {
  final Dio _dio;
  String? _token;

  XboardApi() : _dio = Dio(BaseOptions(baseUrl: xboardBaseUrl)) {
    // The app installs a global HttpOverrides that tunnels every HttpClient
    // through the clash mixed-port once the VPN is started. Our panel API
    // (login, subscription, plans, orders) must NOT depend on a working proxy
    // node — force these requests DIRECT so account/Premium flows keep working
    // even when the selected node is down or flaky.
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = _token;
          }
          handler.next(options);
        },
      ),
    );
  }

  void setToken(String? token) {
    _token = token;
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Network error. Please check your connection.';
      }
      return 'Request failed (${error.response?.statusCode ?? 'unknown'}).';
    }
    return error.toString();
  }

  Future<String> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/passport/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      // `auth_data` is the full Authorization header value (already includes
      // the "Bearer " prefix) — `token` is a separate opaque identifier not
      // used for authenticating subsequent requests.
      final authData = data['auth_data'] as String?;
      if (authData == null) {
        throw XboardApiException('Login response did not include auth_data.');
      }
      _token = authData;
      return authData;
    } catch (e) {
      if (e is XboardApiException) rethrow;
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  Future<void> register(
    String email,
    String password, {
    String? emailCode,
    String? inviteCode,
  }) async {
    try {
      await _dio.post(
        '/passport/auth/register',
        data: {
          'email': email,
          'password': password,
          if (emailCode != null && emailCode.isNotEmpty)
            'email_code': emailCode,
          if (inviteCode != null && inviteCode.isNotEmpty)
            'invite_code': inviteCode,
        },
      );
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  Future<XboardCommConfig> getCommConfig() async {
    try {
      final response = await _dio.get('/guest/comm/config');
      final data = response.data['data'] as Map<String, dynamic>;
      return XboardCommConfig.fromJson(data);
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  Future<void> sendEmailVerifyCode(String email) async {
    try {
      await _dio.post(
        '/passport/comm/sendEmailVerify',
        data: {'email': email},
      );
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  Future<XboardUserInfo> getUserInfo() async {
    try {
      final response = await _dio.get('/user/info');
      final data = response.data['data'] as Map<String, dynamic>;
      return XboardUserInfo.fromJson(data);
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  Future<XboardSubscribeInfo> getSubscribe() async {
    try {
      final response = await _dio.get('/user/getSubscribe');
      final data = response.data['data'] as Map<String, dynamic>;
      return XboardSubscribeInfo.fromJson(data);
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  /// Public plan list — works without auth (`/guest/plan/fetch`). Returns all
  /// plans (including the caller's possibly-unsellable current plan, needed for
  /// the traffic-reset option); callers filter sellable plans for display.
  Future<List<XboardPlan>> getPlans() async {
    try {
      final response = await _dio.get('/guest/plan/fetch');
      final data = response.data['data'] as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(XboardPlan.fromJson)
          .toList();
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  /// The payment methods configured on the panel (e.g. Alipay, WeChat via
  /// EPay). Requires auth.
  Future<List<XboardPaymentMethod>> getPaymentMethods() async {
    try {
      final response = await _dio.get('/user/order/getPaymentMethod');
      final data = response.data['data'] as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(XboardPaymentMethod.fromJson)
          .toList();
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  /// Creates a pending order and returns its `trade_no`. An optional
  /// [couponCode] is validated and applied by the panel at this step.
  Future<String> saveOrder({
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    try {
      final response = await _dio.post(
        '/user/order/save',
        data: {
          'plan_id': planId,
          'period': period,
          if (couponCode != null && couponCode.isNotEmpty)
            'coupon_code': couponCode,
        },
      );
      final data = response.data['data'];
      if (data is String) return data;
      throw XboardApiException('Unexpected order response.');
    } catch (e) {
      if (e is XboardApiException) rethrow;
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  /// Checks out an order against a payment method. For a redirect gateway like
  /// EPay the panel returns a payment URL string; for a balance-only payment it
  /// returns `true`. Returns the URL to open, or `null` when already paid.
  Future<String?> checkoutOrder({
    required String tradeNo,
    required int method,
  }) async {
    try {
      final response = await _dio.post(
        '/user/order/checkout',
        data: {'trade_no': tradeNo, 'method': method},
      );
      final data = response.data['data'];
      if (data is String && data.isNotEmpty) return data;
      // `true` (or a non-string) means the panel completed payment without a
      // redirect — nothing to open.
      return null;
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }

  /// Order status (V2Board/Xboard): 0 pending, 1 processing, 2 cancelled,
  /// 3 completed, 4 discounted. Returns -1 if it can't be read.
  Future<int> getOrderStatus(String tradeNo) async {
    try {
      final response = await _dio.get(
        '/user/order/check',
        queryParameters: {'trade_no': tradeNo},
      );
      final data = response.data['data'];
      if (data is num) return data.toInt();
      return -1;
    } catch (e) {
      throw XboardApiException(_extractErrorMessage(e));
    }
  }
}

final xboardApi = XboardApi();
