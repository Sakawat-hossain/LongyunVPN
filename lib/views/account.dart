import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Standalone Account page (reachable from the Profiles top-bar icon).
class AccountView extends ConsumerWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: context.appLocalizations.account,
      actions: [
        IconButton(
          tooltip: context.appLocalizations.refresh,
          onPressed: () => ref.read(authProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: AccountSummary(),
      ),
    );
  }
}

/// The full account overview (plan, status, data, expiry, devices, balance,
/// Renew / Log out) as an embeddable widget — used both by [AccountView] and
/// inline on the Profiles page. Refreshes account info from the panel when
/// shown; renders nothing when logged out.
class AccountSummary extends ConsumerStatefulWidget {
  const AccountSummary({super.key});

  @override
  ConsumerState<AccountSummary> createState() => _AccountSummaryState();
}

class _AccountSummaryState extends ConsumerState<AccountSummary> {
  @override
  void initState() {
    super.initState();
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
    final theme = Theme.of(context);
    final l = context.appLocalizations;
    final auth = ref.watch(authProvider);
    final user = auth.userInfo;
    if (auth.status != AuthStatus.loggedIn || user == null) {
      return const SizedBox.shrink();
    }

    final sub = auth.subscribeInfo;
    final active = auth.hasActiveSubscription;
    final expiredAt = sub?.expiredAt ?? user.expiredAt;
    final expiryMs = expiredAt != null ? expiredAt * 1000 : null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expired = expiryMs != null && expiryMs < nowMs;
    final daysLeft =
        expiryMs != null ? ((expiryMs - nowMs) / 86400000).ceil() : null;

    final (Color statusColor, String statusText) = !active || expired
        ? (theme.colorScheme.error, expired ? l.statusExpired : l.statusInactive)
        : (Colors.green, l.statusActive);

    final planName = sub?.plan?['name']?.toString() ?? '—';
    final deviceLimit = sub?.plan?['device_limit'];
    final total = sub?.transferEnable ?? user.transferEnable;
    final used = (sub?.u ?? 0) + (sub?.d ?? 0);
    final remaining = (total - used).clamp(0, total);
    final hasTraffic = total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Data usage
        if (hasTraffic) ...[
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.dataLabel, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (used / total).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l.usedOfTotal(_fmtBytes(used), _fmtBytes(total)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      const Spacer(),
                      Text(l.amountLeft(_fmtBytes(remaining)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Details
        _InfoTile(
            icon: Icons.workspace_premium, label: l.planLabel, value: planName),
        _InfoTile(
          icon: Icons.event,
          label: l.expires,
          value: expiryMs != null
              ? '${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(expiryMs))}'
                  '${daysLeft != null && !expired ? '  ·  ${l.nDaysLeft(daysLeft)}' : ''}'
              : (active ? l.noExpiry : '—'),
        ),
        if (deviceLimit != null)
          _InfoTile(
              icon: Icons.devices, label: l.devices, value: '$deviceLimit'),
        _InfoTile(
          icon: Icons.account_balance_wallet,
          label: l.balance,
          value: '¥${(user.balance / 100).toStringAsFixed(2)}',
        ),
        const SizedBox(height: 20),

        // Actions
        FilledButton.icon(
          onPressed: () => ref
              .read(currentPageLabelProvider.notifier)
              .toPage(PageLabel.premium),
          icon: const Icon(Icons.bolt, size: 20),
          label: Text(active ? l.renewUpgrade : l.getAPlan),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => ref.read(authProvider.notifier).logout(),
          icon: const Icon(Icons.logout, size: 20),
          label: Text(l.logOut),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
