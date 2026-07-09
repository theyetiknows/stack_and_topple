import 'package:flutter_test/flutter_test.dart';
import 'package:stack_and_topple/core/input/tilt_processor.dart';
import 'package:stack_and_topple/core/tuning.dart';

/// Feed identical samples until the baseline locks.
TiltProcessor _calibrated(TuningConfig t, double x, double y, double z) {
  final p = TiltProcessor(t)..startCalibration();
  for (var i = 0; i < t.calibrationSamples; i++) {
    p.addCalibrationSample(x, y, z);
  }
  expect(p.isCalibrated, isTrue);
  return p;
}

void main() {
  // No smoothing lag and a small dead-zone: tests read single samples.
  const t = TuningConfig(tiltSmoothing: 1.0, tiltDeadZone: 0.03);

  group('baseline-relative deviation (the couch requirement)', () {
    test('steady at the baseline reads exactly zero', () {
      final p = _calibrated(t, 0, 9.8, 0); // upright portrait
      final out = p.process(0, 9.8, 0);
      expect(out.roll, 0);
      expect(out.pitch, 0);
    });

    test('rolling right from an upright baseline gives +roll', () {
      final p = _calibrated(t, 0, 9.8, 0);
      final out = p.process(2.0, 9.6, 0);
      expect(out.roll, greaterThan(0));
      expect(out.pitch.abs(), lessThan(0.1));
    });

    test('pitching the top away from upright gives +pitch', () {
      final p = _calibrated(t, 0, 9.8, 0);
      final out = p.process(0, 9.4, 2.0);
      expect(out.pitch, greaterThan(0));
      expect(out.roll, 0);
    });

    test('lying on a couch (near-flat baseline) still reads deviations', () {
      // Phone tilted way back: gravity mostly on z. This pose is the NEUTRAL.
      final p = _calibrated(t, 0, 2.0, 9.6);
      expect(p.process(0, 2.0, 9.6).roll, 0); // steady = zero
      final rolled = p.process(2.0, 2.0, 9.4); // same wrist roll as upright
      expect(rolled.roll, greaterThan(0));
    });
  });

  group('shaping', () {
    test('dead-zone flattens micro-jitter to exactly zero', () {
      final p = _calibrated(t, 0, 9.8, 0);
      final out = p.process(0.05, 9.8, 0); // ~0.3° of roll
      expect(out.roll, 0);
    });

    test('extreme tilt clamps to full input', () {
      final p = _calibrated(t, 0, 9.8, 0);
      final out = p.process(9.8, 0.5, 0); // ~87° of roll
      expect(out.roll, 1.0);
    });

    test('low-pass smoothing eases toward the target instead of jumping', () {
      const slow = TuningConfig(tiltSmoothing: 0.2, tiltDeadZone: 0.03);
      final p = _calibrated(slow, 0, 9.8, 0);
      final first = p.process(2.0, 9.6, 0).roll;
      expect(first, greaterThan(0));
      // Full deviation is ~0.59 normalised; one sample at alpha=0.2 must not
      // reach it.
      expect(first, lessThan(0.3));
      var last = first;
      for (var i = 0; i < 30; i++) {
        last = p.process(2.0, 9.6, 0).roll;
      }
      expect(last, greaterThan(first)); // converging up toward the target
    });

    test('rollSign flips the axis without touching the math', () {
      const flipped = TuningConfig(
        tiltSmoothing: 1.0,
        tiltDeadZone: 0.03,
        rollSign: -1.0,
      );
      final p = _calibrated(flipped, 0, 9.8, 0);
      expect(p.process(2.0, 9.6, 0).roll, lessThan(0));
    });
  });
}
