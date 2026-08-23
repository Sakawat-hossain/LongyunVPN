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

class _StartButtonState extends ConsumerState<StartButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  // Slow breathing halo shown only while connected, so the button reads as a
  // live VPN switch at a glance. It is stopped when disconnected so it costs
  // nothing while idle.
  AnimationController? _pulseController;
  late Animation<double> _animation;
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
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOutBack,
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
    return RepaintBoundary(
      child: Theme(
        data: theme.copyWith(
          floatingActionButtonTheme: theme.floatingActionButtonTheme.copyWith(
            sizeConstraints: const BoxConstraints(minWidth: 56, maxWidth: 200),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller!.view,
          builder: (_, child) {
            final textWidth = suspend
                ? globalState.measure
                          .computeTextSize(
                            Text(
                              appLocalizations.suspended,
                              style: context.textTheme.titleMedium,
                            ),
                          )
                          .width +
                      24
                : globalState.measure
                          .computeTextSize(
                            Text(
                              utils.getTimeDifference(DateTime.now()),
                              style: context.textTheme.titleMedium?.toSoftBold,
                            ),
                          )
                          .width +
                      16;
            // Breathing halo behind the button while the tunnel is up. Uses the
            // theme's primary colour so it reads as "protected/live" rather than
            // as a plain play button.
            return AnimatedBuilder(
              animation: _pulseController!,
              builder: (_, fab) {
                final t = _pulseController!.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: _animation.value <= 0.01
                        ? const []
                        : [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.28 * _animation.value * (1 - t * 0.6),
                              ),
                              blurRadius: 14 + 12 * t,
                              spreadRadius: 1 + 4 * t,
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
                tooltip: isStart
                    ? appLocalizations.stopVpn
                    : appLocalizations.startVpn,
                onPressed: () {
                  handleSwitchStart();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16 - 8 * _animation.value,
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _animation,
                      ),
                    ),
                    SizedBox(
                      width: textWidth * _animation.value,
                      child: child!,
                    ),
                  ],
                ),
              ),
            );
          },
          child: suspend
              ? Text(
                  appLocalizations.suspended,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.onPrimaryContainer,
                  ),
                )
              : Consumer(
                  builder: (_, ref, _) {
                    final runTime = ref.watch(runTimeProvider);
                    final text = utils.getTimeText(runTime);
                    return Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.titleMedium?.toSoftBold
                          .copyWith(
                            color: context.colorScheme.onPrimaryContainer,
                          ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
