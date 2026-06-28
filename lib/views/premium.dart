import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumView extends ConsumerStatefulWidget {
  const PremiumView({super.key});

  @override
  ConsumerState<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends ConsumerState<PremiumView> {
  // planId -> selected period key
  final Map<int, String> _selectedPeriod = {};

  @override
  void initState() {
    super.initState();
    Future(() {
      if (!mounted) return;
      ref.read(premiumProvider.notifier).loadPlans();
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
      () => ref.read(premiumProvider.notifier).purchase(
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
      await launchUrl(Uri.parse(payUrl), mode: LaunchMode.externalApplication);
      globalState.showNotifier(l.completePaymentInBrowser);
    } else {
      // No redirect — panel reports it already paid; verify right away.
      await _onRefresh();
    }
  }

  Future<void> _onRefresh() async {
    final l = context.appLocalizations;
    final active = await _safe(
      () => ref.read(premiumProvider.notifier).refreshStatus(),
    );
    if (!mounted) return;
    if (active == true) {
      globalState.showNotifier(l.subscriptionActiveImported);
    } else if (ref.read(premiumProvider).error == null) {
      globalState.showNotifier(l.noActiveSubscriptionYet);
    }
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
    final activePlanId =
        auth.hasActiveSubscription ? auth.userInfo?.planId : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusBanner(auth: auth),
        if (state.pendingTradeNo != null) ...[
          const SizedBox(height: 12),
          _PendingBanner(
            busy: state.isPurchasing,
            onRefresh: _onRefresh,
          ),
        ],
        const SizedBox(height: 12),
        for (final plan in sellablePlans) ...[
          _PlanCard(
            plan: plan,
            selectedPeriod: _selectedPeriod[plan.id] ??
                plan.periodPrices.keys.first,
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
                    style: theme.textTheme.titleMedium?.copyWith(color: onColor),
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
    final price =
        isReset ? resetPriceCents : plan.periodPrices[selectedPeriod];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Chip(
                      label: Text(context.appLocalizations.currentPlan),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.14),
                      side: BorderSide.none,
                      labelStyle: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
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
                    avatar: Icon(Icons.restart_alt,
                        size: 16, color: theme.colorScheme.tertiary),
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

  const _CheckoutSheet({required this.methods});

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
            Text(context.appLocalizations.checkout,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(context.appLocalizations.paymentMethod,
                style: theme.textTheme.labelLarge),
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
              onPressed: onRetry, child: Text(context.appLocalizations.retry)),
        ],
      ),
    );
  }
}
