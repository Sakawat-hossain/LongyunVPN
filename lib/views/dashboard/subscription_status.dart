import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A premium-style subscription summary shown on the dashboard. It is purely
/// additive — it watches [authProvider] and rebuilds automatically whenever the
/// account info is refreshed from the Xboard API. It also pulls fresh account
/// info from the panel each time the dashboard opens, so usage/expiry stay
/// current after a profile/subscription update (which otherwise only refreshes
/// on app restart). Renders nothing when logged out.
class SubscriptionStatusCard extends ConsumerStatefulWidget {
  const SubscriptionStatusCard({super.key});

  @override
  ConsumerState<SubscriptionStatusCard> createState() =>
      _SubscriptionStatusCardState();
}

class _SubscriptionStatusCardState
    extends ConsumerState<SubscriptionStatusCard> {
  @override
  void initState() {
    super.initState();
    // Re-fetch account info (traffic/expiry) whenever the dashboard is shown.
    // refresh() is a no-op unless logged in, and the dashboard is recreated on
    // each visit (keep: false), so returning here after a profile update pulls
    // the latest usage from the panel.
    Future(() {
      if (!mounted) return;
      ref.read(authProvider.notifier).refresh();
    });
  }

  static String _fmtBytes(num bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.status != AuthStatus.loggedIn || auth.userInfo == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final user = auth.userInfo!;
    final sub = auth.subscribeInfo;

    final expiredAt = sub?.expiredAt ?? user.expiredAt;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiryMs = expiredAt != null ? expiredAt * 1000 : null;
    final expired = expiryMs != null && expiryMs < nowMs;
    final daysLeft =
        expiryMs != null ? ((expiryMs - nowMs) / 86400000).ceil() : null;
    final active = auth.hasActiveSubscription;

    // Status → color/label.
    final (Color statusColor, String statusText) = switch (true) {
      _ when !active || expired => (
          const Color(0xFFE53935),
          expired ? l.statusExpired : l.statusInactive
        ),
      _ when daysLeft != null && daysLeft <= 7 => (
          const Color(0xFFFB8C00),
          l.statusExpiringSoon
        ),
      _ => (const Color(0xFF43A047), l.statusActive),
    };

    final planName = sub?.plan?['name']?.toString();
    final total = sub?.transferEnable ?? user.transferEnable;
    final used = (sub?.u ?? 0) + (sub?.d ?? 0);
    final hasTraffic = total > 0;
    final usedFraction = hasTraffic ? (used / total).clamp(0.0, 1.0) : 0.0;
    final remaining = (total - used).clamp(0, total);
    // Surface a reset shortcut when an active plan is running low on data.
    final lowTraffic = active && hasTraffic && usedFraction >= 0.9;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withValues(alpha: 0.10),
              theme.colorScheme.surface.withValues(alpha: 0.0),
            ],
          ),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: lock + Premium + status pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.workspace_premium, color: statusColor),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.premium, style: theme.textTheme.titleMedium),
                    if (planName != null && planName.isNotEmpty)
                      Text(
                        planName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                _StatusPill(color: statusColor, text: statusText),
              ],
            ),
            const SizedBox(height: 18),
            // Expiry + days-left
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.expires,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      expiryMs != null
                          ? DateFormat.yMMMd().format(
                              DateTime.fromMillisecondsSinceEpoch(expiryMs))
                          : l.noExpiry,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const Spacer(),
                _DaysLeft(
                  color: statusColor,
                  expired: expired,
                  daysLeft: daysLeft,
                ),
              ],
            ),
            if (hasTraffic) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usedFraction.toDouble(),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    l.usedOfTotal(_fmtBytes(used), _fmtBytes(total)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l.amountLeft(_fmtBytes(remaining)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                if (lowTraffic) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(currentPageLabelProvider.notifier)
                          .toPage(PageLabel.premium),
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: Text(l.resetData),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.premium),
                    icon: const Icon(Icons.bolt, size: 20),
                    label: Text(expired || !active ? l.renewNow : l.managePlan),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusPill({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DaysLeft extends StatelessWidget {
  final Color color;
  final bool expired;
  final int? daysLeft;

  const _DaysLeft({
    required this.color,
    required this.expired,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    if (daysLeft == null) {
      return Text(l.lifetime,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ));
    }
    if (expired) {
      return Text(l.statusExpired,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$daysLeft',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(l.daysLeftLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}
