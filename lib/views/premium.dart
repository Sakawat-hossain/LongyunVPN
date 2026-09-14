import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:longyunvpn/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:longyunvpn/views/in_app_browser.dart';

class PremiumView extends ConsumerStatefulWidget {
  const PremiumView({super.key});

  @override
  ConsumerState<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends ConsumerState<PremiumView> {
  // planId -> selected period key
  final Map<int, String> _selectedPeriod = {};

  /// Which half of the page is showing. Orders used to sit under the plans, at
  /// the bottom of a long scroll with nothing above it to say so — findable
  /// only by someone who already knew to look.
  _PremiumTab _tab = _PremiumTab.plans;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (!mounted) return;
      ref.read(premiumProvider.notifier).loadPlans();
      ref.read(premiumProvider.notifier).loadOrders();
    });
  }

  String _formatPrice(int cents) {
    final yuan = cents / 100;
    final text = yuan == yuan.roundToDouble()
        ? yuan.toStringAsFixed(0)
        : yuan.toStringAsFixed(2);
    return '¥$text';
  }

  Future<void> _onBuy(XboardPlan plan, String period) async {
    final l = context.appLocalizations;
    final methods = await _safe(
      () => ref.read(premiumProvider.notifier).loadPaymentMethods(),
    );
    if (methods == null || !mounted) return;
    if (methods.isEmpty) {
      globalState.showNotifier(l.noPaymentMethods);
      return;
    }

    final result = await showModalBottomSheet<_CheckoutResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckoutSheet(methods: methods),
    );
    if (result == null || !mounted) return;

    final payUrl = await _safe(
      () => ref
          .read(premiumProvider.notifier)
          .purchase(
            planId: plan.id,
            period: period,
            methodId: result.method.id,
            couponCode: result.coupon,
          ),
    );
    if (!mounted) return;
    // _safe returns null on error; distinguish from a legitimately-null URL by
    // checking the notifier's error.
    final error = ref.read(premiumProvider).error;
    if (error != null) return;

    if (payUrl != null && payUrl.isNotEmpty) {
      // Snapshot the plan before checkout. Coming back cannot be treated as
      // "paid": refreshStatus() reports success for ANY active subscription, so
      // a user who already had a plan and simply pressed Back was told their
      // purchase went through and had the profile re-imported. Only a plan that
      // actually changed — a later expiry, or a different plan — means money
      // moved.
      final before = ref.read(authProvider).subscribeInfo;
      final beforeExpiry = before?.expiredAt;
      final beforePlan = ref.read(authProvider).userInfo?.planId;

      // Checkout runs inside the app. The in-app browser starts from a clean
      // cache/cookie jar so a previous (or abandoned) order can't be replayed,
      // and it exposes an "open in browser" action for gateways that need to
      // hand off to a bank or wallet app.
      await openInApp(context, url: payUrl, title: l.premium);
      if (!mounted) return;

      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      final auth = ref.read(authProvider);
      final changed =
          auth.subscribeInfo?.expiredAt != beforeExpiry ||
          auth.userInfo?.planId != beforePlan;
      if (changed) {
        await _onRefresh();
      } else {
        // Nothing changed on the panel — the order may still be pending, or the
        // user backed out. Say so instead of claiming a purchase, and leave the
        // Refresh action for when the gateway settles.
        //
        // The history still has to be re-read: an order was created either way,
        // and it is the only trace of it the user can get back to. Without this
        // the Orders tab stayed as it was until someone refreshed by hand.
        await ref.read(premiumProvider.notifier).loadOrders();
        if (!mounted) return;
        globalState.showNotifier(l.completePaymentInBrowser);
      }
    } else {
      // No redirect — panel reports it already paid; verify right away.
      await _onRefresh();
    }
  }

  Future<void> _onRefresh() async {
    final l = context.appLocalizations;
    final result = await _safe(
      () => ref.read(premiumProvider.notifier).verifyPendingOrder(),
    );
    if (!mounted || result == null) return;
    // Say what is actually true of the order. Reporting success because the
    // account happens to hold a plan is how an unpaid order used to look paid.
    globalState.showNotifier(switch (result) {
      PendingOrderResult.activated => l.subscriptionActiveImported,
      PendingOrderResult.processing => l.orderProcessingHint,
      PendingOrderResult.unpaid => l.orderNotPaidYet,
      PendingOrderResult.cancelled => l.orderWasCancelled,
      PendingOrderResult.noSubscription => l.noActiveSubscriptionYet,
    });
  }

  /// Runs an async panel call, surfacing any error as a notifier without
  /// throwing. Returns the result, or null on failure.
  Future<T?> _safe<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      if (mounted) globalState.showNotifier(e.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(premiumProvider);
    final auth = ref.watch(authProvider);

    return CommonScaffold(
      title: context.appLocalizations.premium,
      actions: [
        IconButton(
          tooltip: context.appLocalizations.refresh,
          onPressed: state.isPurchasing ? null : _onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _buildBody(state, auth),
    );
  }

  Widget _buildBody(PremiumState state, AuthState auth) {
    if (state.isLoading && state.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.plans.isEmpty) {
      return _ErrorRetry(
        message: state.error ?? context.appLocalizations.noPlansAvailable,
        onRetry: () => ref.read(premiumProvider.notifier).loadPlans(),
      );
    }
    // Plans buyable as new/renewal (the API also returns unsellable legacy
    // plans, which we keep only to resolve the user's current plan for reset).
    final sellablePlans = state.plans
        .where((p) => p.sell && p.periodPrices.isNotEmpty)
        .toList();

    // The user's current plan id — its card gets the extra "Reset traffic"
    // period chip (resetting traffic only makes sense for the plan you own).
    final activePlanId = auth.hasActiveSubscription
        ? auth.userInfo?.planId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The account's own state belongs above the split: it is true of both
        // halves, and an unpaid order is worth seeing whichever tab is open.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              _StatusBanner(auth: auth),
              if (state.pendingTradeNo != null) ...[
                const SizedBox(height: 12),
                _PendingBanner(busy: state.isPurchasing, onRefresh: _onRefresh),
              ],
              const SizedBox(height: 16),
              SegmentedButton<_PremiumTab>(
                segments: [
                  ButtonSegment(
                    value: _PremiumTab.plans,
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: Text(context.appLocalizations.premium),
                  ),
                  ButtonSegment(
                    value: _PremiumTab.orders,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(context.appLocalizations.orderHistory),
                  ),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
              // Breathing room under the switch. The first plan used to begin
              // immediately below it, so the two read as one stuck-together
              // block instead of a control and the thing it controls.
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          // The list slides under a soft edge instead of stopping at a hard
          // line beneath the switch. dstIn keeps the page's own background
          // showing through, so this fades whatever is behind it rather than
          // painting a band of one colour over it.
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black],
              stops: [0, 0.035],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: switch (_tab) {
              _PremiumTab.plans => _buildPlans(
                state,
                sellablePlans,
                activePlanId,
              ),
              _PremiumTab.orders => _buildOrders(state),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlans(
    PremiumState state,
    List<XboardPlan> sellablePlans,
    int? activePlanId,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final plan in sellablePlans) ...[
          _PlanCard(
            plan: plan,
            selectedPeriod:
                _selectedPeriod[plan.id] ?? plan.periodPrices.keys.first,
            formatPrice: _formatPrice,
            busy: state.isPurchasing,
            isCurrent: plan.id == activePlanId,
            resetPriceCents: plan.id == activePlanId ? plan.resetPrice : null,
            onPeriodChange: (period) =>
                setState(() => _selectedPeriod[plan.id] = period),
            onBuy: () => _onBuy(
              plan,
              _selectedPeriod[plan.id] ?? plan.periodPrices.keys.first,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildOrders(PremiumState state) {
    if (state.ordersLoading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.orders.isEmpty) {
      // Now that the list has a tab of its own, an empty state is the honest
      // answer. It could stay hidden while it was an unlabelled section at the
      // bottom of the plans; a tab that opens onto nothing cannot.
      return _EmptyOrders(
        onRefresh: () =>
            _safe(() => ref.read(premiumProvider.notifier).loadOrders()),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(premiumProvider.notifier).loadOrders(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: state.orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) => _OrderTile(
          order: state.orders[index],
          formatPrice: _formatPrice,
          onPay: _onPayOrder,
          onCancel: _onCancelOrder,
        ),
      ),
    );
  }

  /// Reopens checkout for an order that was created but never paid.
  ///
  /// Backing out of the payment page used to strand the order: the banner was
  /// the only route to it, and once that was gone there was no way to pay it
  /// from inside the app at all.
  Future<void> _onPayOrder(XboardOrder order) async {
    final l = context.appLocalizations;
    final methods = await _safe(
      () => ref.read(premiumProvider.notifier).loadPaymentMethods(),
    );
    if (methods == null || !mounted) return;
    if (methods.isEmpty) {
      globalState.showNotifier(l.noPaymentMethods);
      return;
    }
    final result = await showModalBottomSheet<_CheckoutResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckoutSheet(methods: methods, showCoupon: false),
    );
    if (result == null || !mounted) return;

    final payUrl = await _safe(
      () => ref
          .read(premiumProvider.notifier)
          .checkoutExisting(tradeNo: order.tradeNo, methodId: result.method.id),
    );
    if (!mounted) return;
    if (payUrl != null && payUrl.isNotEmpty) {
      await openInApp(context, url: payUrl, title: l.premium);
      if (!mounted) return;
    }
    await _onRefresh();
  }

  Future<void> _onCancelOrder(XboardOrder order) async {
    final l = context.appLocalizations;
    final confirmed = await globalState.showMessage(
      title: l.cancelOrder,
      message: TextSpan(text: order.tradeNo),
    );
    if (confirmed != true || !mounted) return;
    // _safe reports failure as null, which a void result cannot express, so the
    // call returns a value of its own.
    final done = await _safe(() async {
      await ref.read(premiumProvider.notifier).cancelOrder(order.tradeNo);
      return true;
    });
    if (!mounted || done != true) return;
    globalState.showNotifier(l.orderCancelled_success);
  }
}

/// Shown when the Orders tab has nothing in it.
class _EmptyOrders extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyOrders({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l.noOrders,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(l.refresh),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final XboardOrder order;
  final String Function(int cents) formatPrice;
  final Future<void> Function(XboardOrder order) onPay;
  final Future<void> Function(XboardOrder order) onCancel;

  const _OrderTile({
    required this.order,
    required this.formatPrice,
    required this.onPay,
    required this.onCancel,
  });

  /// Panel status codes: 0 pending, 1 processing, 2 cancelled, 3 completed,
  /// 4 discounted (absorbed into an upgrade).
  (String, Color) _status(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = Theme.of(context).colorScheme;
    return switch (order.status) {
      0 => (l.orderPending, const Color(0xFFFB8C00)),
      1 => (l.orderProcessing, scheme.primary),
      2 => (l.orderCancelled, scheme.outline),
      3 => (l.orderCompleted, const Color(0xFF43A047)),
      4 => (l.orderDiscounted, scheme.outline),
      _ => ('', scheme.outline),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusText, statusColor) = _status(context);
    final periodLabel = xboardPeriods[order.period];
    final created = order.createdAt;
    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.planName ?? order.tradeNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: statusColor.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    statusText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (periodLabel != null) ...[
                  Text(
                    periodLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (created != null)
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(created * 1000),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                Text(
                  formatPrice(order.totalAmount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (order.isPayable) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onCancel(order),
                    child: Text(context.appLocalizations.cancelOrder),
                  ),
                  const SizedBox(width: 8),
                  // The way back into a payment that was abandoned.
                  FilledButton.tonal(
                    onPressed: () => onPay(order),
                    child: Text(context.appLocalizations.payNow),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final AuthState auth;

  const _StatusBanner({required this.auth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = auth.hasActiveSubscription;
    final expiredAt = auth.userInfo?.expiredAt;
    final l = context.appLocalizations;
    String subtitle;
    if (active) {
      if (expiredAt == null) {
        subtitle = l.lifetimePlan;
      } else {
        final date = DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
        subtitle = l.expiresDate(DateFormat.yMMMd().format(date));
      }
    } else {
      subtitle = l.noActivePlanChoose;
    }
    final color = active
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = active
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              active ? Icons.verified_user : Icons.info_outline,
              color: onColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? l.subscriptionActive : l.noSubscription,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final bool busy;
  final VoidCallback onRefresh;

  const _PendingBanner({required this.busy, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.appLocalizations.waitingForPayment,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: busy ? null : onRefresh,
              child: Text(context.appLocalizations.ivePaid),
            ),
          ],
        ),
      ),
    );
  }
}

String _periodLabel(BuildContext context, String key) {
  final l = context.appLocalizations;
  switch (key) {
    case 'month_price':
      return l.periodMonthly;
    case 'quarter_price':
      return l.periodQuarterly;
    case 'half_year_price':
      return l.periodHalfYearly;
    case 'year_price':
      return l.periodYearly;
    case 'two_year_price':
      return l.periodTwoYears;
    case 'three_year_price':
      return l.periodThreeYears;
    case 'onetime_price':
      return l.periodOneTime;
    default:
      return xboardPeriods[key] ?? key;
  }
}

class _PlanCard extends StatelessWidget {
  final XboardPlan plan;
  final String selectedPeriod;
  final String Function(int cents) formatPrice;
  final bool busy;

  /// Whether this is the user's currently-subscribed plan (marks it and turns
  /// "Buy" into "Renew").
  final bool isCurrent;

  /// Reset price (cents) — non-null only for the user's current plan, which
  /// adds a "Reset traffic" option to the period chips (matching the panel).
  final int? resetPriceCents;
  final ValueChanged<String> onPeriodChange;
  final VoidCallback onBuy;

  const _PlanCard({
    required this.plan,
    required this.selectedPeriod,
    required this.formatPrice,
    required this.busy,
    required this.isCurrent,
    required this.resetPriceCents,
    required this.onPeriodChange,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReset = selectedPeriod == xboardResetPeriod;
    final price = isReset ? resetPriceCents : plan.periodPrices[selectedPeriod];
    // The plan the user owns is marked three ways: the "Current plan" chip, a
    // faint diagonal wash, and this border. It used to be 2pt of full-strength
    // primary, which on the light container read as a hard bright outline
    // drawn around the card rather than as part of it — the loudest thing on a
    // page whose job is to be read. Softened to a tint, since the chip and the
    // wash were already saying it. primary comes from the app's seed colour, so
    // this still tracks the theme instead of hardcoding a hex value.
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.45),
                width: 1.5,
              )
            : BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Container(
        // Same diagonal wash as the dashboard subscription card, so the plan
        // you own is marked the same way in both places.
        decoration: isCurrent
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.14),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              )
            : null,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name, style: theme.textTheme.titleLarge),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(
                      label: Text(context.appLocalizations.currentPlan),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      // Solid brand fill so the badge reads as a state, not a tag.
                      backgroundColor: theme.colorScheme.primary,
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                for (final tag in plan.tags)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            if (plan.transferEnable != null || plan.speedLimit != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (plan.transferEnable != null)
                    '${plan.transferEnable!.toStringAsFixed(0)} GB',
                  if (plan.speedLimit != null)
                    '${plan.speedLimit!.toStringAsFixed(0)} Mbps',
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final f in plan.features)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f.support ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color: f.support
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.feature,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in plan.periodPrices.entries)
                  ChoiceChip(
                    selected: entry.key == selectedPeriod,
                    onSelected: busy ? null : (_) => onPeriodChange(entry.key),
                    label: Text(
                      '${_periodLabel(context, entry.key)} · '
                      '${formatPrice(entry.value)}',
                    ),
                  ),
                if (resetPriceCents != null && resetPriceCents! > 0)
                  ChoiceChip(
                    selected: isReset,
                    onSelected: busy
                        ? null
                        : (_) => onPeriodChange(xboardResetPeriod),
                    avatar: Icon(
                      Icons.restart_alt,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    label: Text(
                      '${context.appLocalizations.resetTraffic} · '
                      '${formatPrice(resetPriceCents!)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onBuy,
                child: Text(
                  price == null
                      ? context.appLocalizations.buy
                      : '${isReset ? context.appLocalizations.resetTraffic : (isCurrent ? context.appLocalizations.renew : context.appLocalizations.buy)} · ${formatPrice(price)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutResult {
  final XboardPaymentMethod method;
  final String? coupon;

  const _CheckoutResult({required this.method, this.coupon});
}

class _CheckoutSheet extends StatefulWidget {
  final List<XboardPaymentMethod> methods;

  /// Off when paying an order that already exists: its price was fixed when it
  /// was created, and a coupon field there would take input the panel ignores.
  final bool showCoupon;

  const _CheckoutSheet({required this.methods, this.showCoupon = true});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  late XboardPaymentMethod _method = widget.methods.first;
  final _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        // Lift above the keyboard when the coupon field is focused.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.appLocalizations.checkout,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.appLocalizations.paymentMethod,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final method in widget.methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  _method.id == method.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _method.id == method.id
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(method.name),
                onTap: () => setState(() => _method = method),
              ),
            const SizedBox(height: 8),
            if (widget.showCoupon) ...[
              TextField(
                controller: _couponController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: context.appLocalizations.couponCodeOptional,
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _CheckoutResult(
                    method: _method,
                    coupon: _couponController.text.trim().isEmpty
                        ? null
                        : _couponController.text.trim(),
                  ),
                ),
                child: Text(context.appLocalizations.continueToPayment),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(context.appLocalizations.retry),
          ),
        ],
      ),
    );
  }
}

/// The two halves of the Premium page.
enum _PremiumTab { plans, orders }
