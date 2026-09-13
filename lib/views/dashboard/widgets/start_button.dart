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
/// Corner radius of the button in both states. 18 against a 56pt box is the
/// squircle proportion the app mark uses, rather than a circle or a stadium.
const double _cornerRadius = 18;

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

    // Resting is a plain circle with the icon and nothing else, so there is no
    // label to measure and the running width collapses to zero on the way back.
    // The running width is measured against a sample timer rather than the live
    // one, which keeps the pill steady while the seconds tick.
    final labelStyle = context.textTheme.titleMedium?.toSoftBold;
    double measure(String text, double padding) =>
        globalState.measure
            .computeTextSize(Text(text, style: labelStyle))
            .width +
        padding;
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
          builder: (_, _) {
            // The spring curve overshoots past 0 and 1, which is fine for
            // motion and wrong for anything interpolated: a colour or a width
            // computed from it would leave its own range.
            final t = _controller!.value.clamp(0.0, 1.0);
            final eased = Curves.easeOut.transform(t);
            final textWidth = runningWidth * eased;
            // Off reads as inactive, on reads as live. Colour was carrying none
            // of this before - both states were the same filled pill, and only
            // a faint halo told them apart.
            final background = Color.lerp(
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.primaryContainer,
              t,
            )!;
            // Contrast is taken from the pill that actually got painted, not
            // from the scheme's on-colour. The running pill resolves light in
            // this theme while onPrimaryContainer is light too, so the timer was
            // being drawn light-on-light and could not be read.
            final foreground =
                ThemeData.estimateBrightnessForColor(background) ==
                    Brightness.dark
                ? Colors.white
                : Colors.black87;
            // The mark's red, once the tunnel is up. Only the glyph takes it —
            // the pill keeps the theme's colour, so the red reads as a state
            // and not as a second accent.
            final iconColor = Color.lerp(foreground, appBrandColor, t)!;
            return AnimatedBuilder(
              animation: _pulseController!,
              builder: (_, fab) {
                final pulse = _pulseController!.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cornerRadius),
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
                // A rounded superellipse, not a circle - the same corner the
                // app mark uses in the sidebar, so the button belongs to the
                // rest of the UI instead of being the one round thing in it.
                // The radius is fixed, so resting is a squircle and running is
                // the same corner stretched.
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(_cornerRadius),
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
                      // Even padding while resting keeps the circle round; the
                      // right side tightens as the timer slides out.
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16 - 8 * eased,
                      ),
                      alignment: Alignment.centerLeft,
                      // One glyph in both states - the power symbol - with the
                      // state carried by its colour rather than by swapping it
                      // for a different shape.
                      child: Icon(
                        Icons.power_settings_new,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(
                      width: textWidth,
                      child: _Label(
                        style: labelStyle?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The timer, or the suspended notice, or nothing at all while resting.
///
/// The colour arrives on [style] rather than being inherited. The button sets
/// foregroundColor, but a text style taken from the theme carries a colour of
/// its own, and that colour wins over the inherited one - which is how the
/// timer came to be drawn white on a light pill and could not be read.
class _Label extends ConsumerWidget {
  final TextStyle? style;

  const _Label({required this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final String text;
    if (ref.watch(suspendProvider)) {
      text = appLocalizations.suspended;
    } else if (ref.watch(isStartProvider)) {
      text = utils.getTimeText(ref.watch(runTimeProvider));
    } else {
      // Nothing while resting: the button is just the mark then, and the
      // tooltip is what names the action.
      text = '';
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.visible,
      style: style,
    );
  }
}
