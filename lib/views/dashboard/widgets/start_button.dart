import 'package:longyunvpn/common/common.dart';
import 'package:longyunvpn/enum/enum.dart';
import 'package:longyunvpn/providers/providers.dart';
import 'package:longyunvpn/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

// Two controllers live here - the press transition and the breathing halo - so
// this needs the plural ticker provider. It declared SingleTickerProviderStateMixin
// while creating both, which asserts in debug ("multiple tickers were created")
// and in release leaves the second controller's ticker outside the mixin's
// bookkeeping, so it is never muted when the route is hidden.
class _StartButtonState extends ConsumerState<StartButton>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  // Slow breathing halo shown only while connected, so the button reads as a
  // live VPN switch at a glance. It is stopped when disconnected so it costs
  // nothing while idle.
  AnimationController? _pulseController;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = ref.read(isStartProvider);
    _controller = AnimationController(
      vsync: this,
      value: isStart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    ref.listenManual(isStartProvider, (prev, next) {
      if (next != isStart) {
        isStart = next;
        updateController();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _pulseController?.dispose();
    _pulseController = null;
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    updateController();
    debouncer.call(FunctionTag.updateStatus, () {
      ref
          .read(setupActionProvider.notifier)
          .updateStatus(isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  void updateController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isStart && mounted) {
        _controller?.forward();
        // Only animate the halo while connected.
        _pulseController?.repeat(reverse: true);
      } else {
        _controller?.reverse();
        _pulseController?.stop();
        _pulseController?.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return Container();
    }
    final suspend = ref.watch(suspendProvider);
    final theme = Theme.of(context);
    final appLocalizations = context.appLocalizations;

    // The label is measured for both states so the pill can morph between them
    // rather than jump. The running state's width is measured against a sample
    // timer rather than the live one, which keeps the width steady while the
    // seconds tick.
    final labelStyle = context.textTheme.titleMedium?.toSoftBold;
    double measure(String text, double padding) =>
        globalState.measure
            .computeTextSize(Text(text, style: labelStyle))
            .width +
        padding;
    final restingWidth = measure(appLocalizations.connectAction, 16);
    final runningWidth = suspend
        ? measure(appLocalizations.suspended, 24)
        : measure(utils.getTimeDifference(DateTime.now()), 16);

    return RepaintBoundary(
      child: Theme(
        data: theme.copyWith(
          floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
            // Roomy enough for the longest translated label - Russian's
            // "Подключить" is a good deal wider than "Connect".
            sizeConstraints: const BoxConstraints(minWidth: 56, maxWidth: 260),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller!.view,
          builder: (_, child) {
            // The spring curve overshoots past 0 and 1, which is fine for
            // motion and wrong for anything interpolated: a colour or a width
            // computed from it would leave its own range.
            final t = _controller!.value.clamp(0.0, 1.0);
            final eased = Curves.easeOut.transform(t);
            final textWidth =
                restingWidth + (runningWidth - restingWidth) * eased;
            // Off reads as inactive, on reads as live. Colour was carrying none
            // of this before - both states were the same filled pill, and only
            // a faint halo told them apart.
            final background = Color.lerp(
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.primaryContainer,
              t,
            )!;
            final foreground = Color.lerp(
              theme.colorScheme.onSurfaceVariant,
              theme.colorScheme.onPrimaryContainer,
              t,
            )!;
            return AnimatedBuilder(
              animation: _pulseController!,
              builder: (_, fab) {
                final pulse = _pulseController!.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: t <= 0.01
                        ? const []
                        : [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.28 * t * (1 - pulse * 0.6),
                              ),
                              blurRadius: 14 + 12 * pulse,
                              spreadRadius: 1 + 4 * pulse,
                            ),
                          ],
                  ),
                  child: fab,
                );
              },
              child: FloatingActionButton(
                clipBehavior: Clip.antiAlias,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                heroTag: null,
                backgroundColor: background,
                foregroundColor: foreground,
                elevation: 2 + 2 * t,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  // An outline while resting, fading out as the pill fills in.
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 1 - t,
                    ),
                  ),
                ),
                tooltip: isStart
                    ? appLocalizations.disconnectAction
                    : appLocalizations.connectAction,
                onPressed: () {
                  handleSwitchStart();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      alignment: Alignment.centerLeft,
                      // Power, not play. A media glyph reads as "play something"
                      // and gave first-time users nothing to connect this button
                      // to the VPN being on or off.
                      child: const Icon(Icons.power_settings_new),
                    ),
                    SizedBox(width: textWidth, child: child!),
                  ],
                ),
              ),
            );
          },
          // One consumer covers all three labels. The resting label is the
          // whole point of the change: the button used to say nothing at all
          // until after it had been switched on, so the state that needed
          // explaining was the state with no words on it.
          child: Consumer(
            builder: (_, ref, _) {
              final started = ref.watch(isStartProvider);
              final isSuspended = ref.watch(suspendProvider);
              final String text;
              if (isSuspended) {
                text = appLocalizations.suspended;
              } else if (started) {
                text = utils.getTimeText(ref.watch(runTimeProvider));
              } else {
                text = appLocalizations.connectAction;
              }
              return Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.visible,
                // No colour here: the button's foregroundColor supplies it, so
                // the label tracks the resting/running transition with it.
                style: labelStyle,
              );
            },
          ),
        ),
      ),
    );
  }
}
