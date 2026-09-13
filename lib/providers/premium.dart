import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action.dart';
import 'app.dart';
import 'auth.dart';

class PremiumState {
  final List<XboardPlan> plans;
  final bool isLoading;
  final String? error;

  /// The order currently awaiting payment, if any.
  final String? pendingTradeNo;
  final bool isPurchasing;

  /// The account's order history, newest first.
  final List<XboardOrder> orders;
  final bool ordersLoading;

  const PremiumState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
    this.pendingTradeNo,
    this.isPurchasing = false,
    this.orders = const [],
    this.ordersLoading = false,
  });

  PremiumState copyWith({
    List<XboardPlan>? plans,
    bool? isLoading,
    String? error,
    // Passing `clearPendingTradeNo: true` resets the pending order (the
    // `??` fallback below can't distinguish "leave unchanged" from "clear").
    String? pendingTradeNo,
    bool clearPendingTradeNo = false,
    bool? isPurchasing,
    List<XboardOrder>? orders,
    bool? ordersLoading,
  }) {
    return PremiumState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pendingTradeNo:
          clearPendingTradeNo ? null : (pendingTradeNo ?? this.pendingTradeNo),
      isPurchasing: isPurchasing ?? this.isPurchasing,
      orders: orders ?? this.orders,
      ordersLoading: ordersLoading ?? this.ordersLoading,
    );
  }
}

class PremiumNotifier extends Notifier<PremiumState> {
  @override
  PremiumState build() => const PremiumState();

  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plans = await xboardApi.getPlans();
      state = state.copyWith(plans: plans, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads the order history. Never fatal: the plans on this page are what the
  /// user came for, and a history that failed to load must not take them with
  /// it — the section just stays empty.
  Future<void> loadOrders() async {
    state = state.copyWith(ordersLoading: true);
    try {
      final orders = await xboardApi.getOrders();
      state = state.copyWith(orders: orders, ordersLoading: false);
    } catch (e) {
      commonPrint.log('order history failed to load: $e',
          logLevel: LogLevel.warning);
      state = state.copyWith(ordersLoading: false);
    }
  }

  /// Cancels an unpaid order, then re-reads the list so the row reflects it.
  Future<void> cancelOrder(String tradeNo) async {
    await xboardApi.cancelOrder(tradeNo);
    if (state.pendingTradeNo == tradeNo) {
      state = state.copyWith(clearPendingTradeNo: true);
    }
    await loadOrders();
  }

  Future<List<XboardPaymentMethod>> loadPaymentMethods() {
    return xboardApi.getPaymentMethods();
  }

  /// Creates the order and checks it out against [methodId]. Returns the
  /// payment URL to open (redirect gateways like EPay), or null when the panel
  /// reports the order already paid (e.g. balance payment). Throws on failure.
  Future<String?> purchase({
    required int planId,
    required String period,
    required int methodId,
    String? couponCode,
  }) async {
    state = state.copyWith(isPurchasing: true, error: null);
    try {
      final tradeNo = await xboardApi.saveOrder(
        planId: planId,
        period: period,
        couponCode: couponCode,
      );
      final payUrl = await xboardApi.checkoutOrder(
        tradeNo: tradeNo,
        method: methodId,
      );
      state = state.copyWith(isPurchasing: false, pendingTradeNo: tradeNo);
      return payUrl;
    } catch (e) {
      state = state.copyWith(isPurchasing: false, error: e.toString());
      rethrow;
    }
  }

  /// Re-checks subscription status after the user reports paying. When the
  /// account is now active, imports the subscribe URL as a LongyunVPN profile
  /// (reusing the existing add/update-from-URL logic) and routes Home. Returns
  /// true if the subscription is active.
  Future<bool> refreshStatus() async {
    await ref.read(authProvider.notifier).refresh();
    final auth = ref.read(authProvider);
    if (!auth.hasActiveSubscription) return false;
    final subscribeUrl = auth.subscribeInfo?.subscribeUrl;
    if (subscribeUrl != null && subscribeUrl.isNotEmpty) {
      await ref
          .read(profilesActionProvider.notifier)
          .addProfileFormURL(subscribeUrl);
    }
    // addProfileFormURL jumps to the Profiles tab; the spec wants the user on
    // Home to connect, so land there instead.
    ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.dashboard);
    state = state.copyWith(clearPendingTradeNo: true);
    await loadOrders();
    return true;
  }
}

final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(
  PremiumNotifier.new,
);
