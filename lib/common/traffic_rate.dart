import 'package:longyunvpn/models/models.dart';

/// Turns the core's cumulative byte counters into a per-second rate.
///
/// The core also publishes a ready-made per-second figure, but it is a snapshot
/// refreshed on a one-second ticker of the core's own, while the UI samples on a
/// separate one-second timer. Two free-running clocks at the same frequency
/// drift against each other, and as the phase slides one poll re-reads a
/// snapshot it has already reported while the next skips a whole second that is
/// never reported at all. A duplicate, then a gap, repeating — which draws a
/// stepping line on a perfectly steady transfer.
///
/// Measuring a counter delta against the time that actually elapsed cannot
/// alias: nothing is double-counted, nothing is dropped, and a poll that arrives
/// late is corrected by its own longer interval instead of reading as a spike.
class TrafficRateMeter {
  Traffic? _total;
  int? _atMs;
  bool? _onlyProxy;

  /// Drops the baseline so the next sample starts a fresh interval.
  ///
  /// Needed whenever the counters are reset or the measurement would span a
  /// window the user did not watch — a stop/start, or a spell in the background.
  /// Measuring across a five-minute gap reports the average over those five
  /// minutes as the current speed.
  void reset() {
    _total = null;
    _atMs = null;
    _onlyProxy = null;
  }

  /// Records [total] as the new baseline and returns the speed since the
  /// previous one.
  ///
  /// Returns null when there is no interval worth measuring across: the first
  /// sample, a change of accounting scope, two samples inside the same
  /// millisecond, or counters that moved backwards because they were reset
  /// underneath us. The baseline is always updated, so the following sample
  /// measures normally.
  Traffic? sample(
    Traffic total, {
    required bool onlyProxy,
    required int nowMs,
  }) {
    final previous = _total;
    final previousMs = _atMs;
    final scopeChanged = _onlyProxy != onlyProxy;

    _total = total;
    _atMs = nowMs;
    _onlyProxy = onlyProxy;

    if (previous == null || previousMs == null || scopeChanged) {
      return null;
    }
    final elapsedMs = nowMs - previousMs;
    if (elapsedMs <= 0) {
      return null;
    }
    final up = total.up - previous.up;
    final down = total.down - previous.down;
    if (up < 0 || down < 0) {
      return null;
    }
    return Traffic(up: up * 1000 / elapsedMs, down: down * 1000 / elapsedMs);
  }
}
