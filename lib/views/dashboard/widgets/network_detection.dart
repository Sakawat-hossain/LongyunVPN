import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  /// Your public IP identifies you, so it stays hidden until asked for —
  /// handy when screen-sharing or sending a screenshot.
  bool _ipVisible = false;

  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final networkDetection = ref.watch(networkDetectionProvider);
    final ipInfo = networkDetection.ipInfo;
    final isLoading = networkDetection.isLoading;
    final emojiTextStyle = context.textTheme.titleMedium?.toLight.copyWith(
      fontFamily: FontFamily.twEmoji.value,
    );
    final titleTextStyle = context.colorScheme.onSurfaceVariant;
    final descTextStyle = context.textTheme.titleSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        // The card describes where your traffic is coming out, so tapping it
        // goes to the servers page — the place you'd act on that. The eye
        // button stops the tap from bubbling, so toggling doesn't navigate.
        onPressed: () => ref
            .read(currentPageLabelProvider.notifier)
            .toPage(PageLabel.proxies),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: globalState.measure.titleMediumHeight + 16,
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ipInfo != null
                      ? Text(
                          _countryCodeToEmoji(ipInfo.countryCode),
                          style: emojiTextStyle,
                        )
                      : Icon(Icons.network_check, color: titleTextStyle),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: TooltipText(
                      text: Text(
                        appLocalizations.networkDetection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: descTextStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  AspectRatio(
                    aspectRatio: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      // Show/hide the public IP. Replaces an info button whose
                      // only job was to pop a dialog saying the lookup is
                      // third-party and indicative — that caveat is now this
                      // button's tooltip.
                      tooltip:
                          '${_ipVisible ? appLocalizations.hide : appLocalizations.show}\n${appLocalizations.detectionTip}',
                      onPressed: ipInfo == null
                          ? null
                          : () => setState(() => _ipVisible = !_ipVisible),
                      icon: Icon(
                        size: 16.ap,
                        _ipVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: baseInfoEdgeInsets.copyWith(top: 0),
              child: SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: FadeThroughBox(
                  child: ipInfo != null
                      ? TooltipText(
                          text: Text(
                            // Same character count when masked, so the row
                            // doesn't resize as it's toggled.
                            _ipVisible
                                ? ipInfo.ip
                                : '•' * ipInfo.ip.length,
                            style: context.textTheme.bodyMedium?.toLight
                                .adjustSize(1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : isLoading == false && ipInfo == null
                      ? Text(
                          'Timeout',
                          style: context.textTheme.bodyMedium
                              ?.copyWith(color: Colors.red)
                              .adjustSize(1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Container(
                          padding: const EdgeInsets.all(2),
                          child: const AspectRatio(
                            aspectRatio: 1,
                            child: CommonCircleLoading(),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
