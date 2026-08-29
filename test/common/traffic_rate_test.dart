import 'package:flutter_test/flutter_test.dart';
import 'package:longyunvpn/common/traffic_rate.dart';
import 'package:longyunvpn/models/models.dart';

void main() {
  group('TrafficRateMeter', () {
    test('reports nothing until it has an interval to measure', () {
      final meter = TrafficRateMeter();
      expect(
        meter.sample(
          const Traffic(up: 100, down: 200),
          onlyProxy: false,
          nowMs: 1000,
        ),
        isNull,
      );
    });

    test('divides the counter delta by the elapsed time', () {
      final meter = TrafficRateMeter();
      meter.sample(const Traffic(up: 0, down: 0), onlyProxy: false, nowMs: 0);

      final speed = meter.sample(
        const Traffic(up: 1000, down: 4000),
        onlyProxy: false,
        nowMs: 1000,
      );

      expect(speed!.up, 1000);
      expect(speed.down, 4000);
    });

    test('a late sample reads as its own interval, not as a spike', () {
      // The regression this class exists for. A poll that arrives at 2s instead
      // of 1s has two seconds of bytes behind it; charging them all to one
      // second is what drew the peaks. Steady 1000 B/s must read as 1000 B/s
      // however late the poll lands.
      final meter = TrafficRateMeter();
      meter.sample(const Traffic(up: 0, down: 0), onlyProxy: false, nowMs: 0);

      final speed = meter.sample(
        const Traffic(up: 2000, down: 2000),
        onlyProxy: false,
        nowMs: 2000,
      );

      expect(speed!.up, 1000);
      expect(speed.down, 1000);
    });

    test('an early sample does not read as a dip', () {
      final meter = TrafficRateMeter();
      meter.sample(const Traffic(up: 0, down: 0), onlyProxy: false, nowMs: 0);

      final speed = meter.sample(
        const Traffic(up: 500, down: 500),
        onlyProxy: false,
        nowMs: 500,
      );

      expect(speed!.up, 1000);
      expect(speed.down, 1000);
    });

    test('irregular polling still averages to the true rate', () {
      // Ten samples at wildly uneven intervals over ten seconds of a steady
      // 1000 B/s transfer. Every one of them must read 1000 B/s: that is the
      // property the core's own per-second snapshot could not provide, because
      // its ticker and the UI timer drift apart.
      final meter = TrafficRateMeter();
      const rate = 1000;
      final offsets = [0, 700, 1900, 2000, 3400, 4100, 6000, 6050, 8300, 10000];

      Traffic? last;
      for (final ms in offsets) {
        last = meter.sample(
          Traffic(up: rate * ms / 1000, down: rate * ms / 1000),
          onlyProxy: false,
          nowMs: ms,
        );
        if (ms != offsets.first) {
          expect(last!.up, closeTo(rate, 0.0001));
          expect(last.down, closeTo(rate, 0.0001));
        }
      }
      expect(last, isNotNull);
    });

    test('a counter reset is skipped rather than reported as negative', () {
      final meter = TrafficRateMeter();
      meter.sample(
        const Traffic(up: 5000, down: 5000),
        onlyProxy: false,
        nowMs: 0,
      );

      expect(
        meter.sample(
          const Traffic(up: 0, down: 0),
          onlyProxy: false,
          nowMs: 1000,
        ),
        isNull,
      );

      // ...and the sample after it measures normally against the new baseline.
      final speed = meter.sample(
        const Traffic(up: 100, down: 100),
        onlyProxy: false,
        nowMs: 2000,
      );
      expect(speed!.up, 100);
    });

    test('switching accounting scope starts a new baseline', () {
      // Proxy-only totals are a different, smaller series than the overall
      // ones. Measuring one against the other would report a large negative or
      // positive jump that never happened.
      final meter = TrafficRateMeter();
      meter.sample(
        const Traffic(up: 9000, down: 9000),
        onlyProxy: false,
        nowMs: 0,
      );

      expect(
        meter.sample(
          const Traffic(up: 10, down: 10),
          onlyProxy: true,
          nowMs: 1000,
        ),
        isNull,
      );
    });

    test('two samples in the same millisecond are skipped', () {
      final meter = TrafficRateMeter();
      meter.sample(const Traffic(up: 0, down: 0), onlyProxy: false, nowMs: 500);

      expect(
        meter.sample(
          const Traffic(up: 10, down: 10),
          onlyProxy: false,
          nowMs: 500,
        ),
        isNull,
      );
    });

    test('reset forces the next sample to seed a fresh baseline', () {
      final meter = TrafficRateMeter();
      meter.sample(const Traffic(up: 0, down: 0), onlyProxy: false, nowMs: 0);
      meter.reset();

      // Without the reset this would report the average over the whole gap.
      expect(
        meter.sample(
          const Traffic(up: 600000, down: 600000),
          onlyProxy: false,
          nowMs: 300000,
        ),
        isNull,
      );
    });
  });
}
