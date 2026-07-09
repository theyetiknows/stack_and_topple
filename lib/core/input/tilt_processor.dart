import 'dart:math' as math;

import '../tuning.dart';

/// Converts raw gravity-vector samples into calibrated, normalised tilt input.
///
/// Pure Dart (no sensor-plugin imports) so the math is unit-testable and the
/// sensor source is swappable. Pipeline per sample:
///   1. roll/pitch angles relative to the CALIBRATED baseline pose — never
///      relative to true horizontal, so any comfortable pose (couch, bed,
///      upright) is a valid neutral;
///   2. low-pass smoothing to kill sensor jitter;
///   3. dead-zone so a steady hand reads as exactly zero;
///   4. normalisation: [TuningConfig.tiltMaxAngle] radians of deviation = ±1.
class TiltProcessor {
  TiltProcessor(this.tuning);

  final TuningConfig tuning;

  bool get isCalibrated => _calibrated;
  bool _calibrated = false;

  // Baseline angles captured at calibration.
  double _baseRoll = 0;
  double _basePitch = 0;

  // Smoothed deviation state (radians).
  double _roll = 0;
  double _pitch = 0;

  // Calibration accumulation.
  final List<double> _calRoll = [];
  final List<double> _calPitch = [];

  /// Roll angle (rad) of a gravity vector: rotation about the device's long
  /// axis. atan2 against the magnitude of the other two components keeps it
  /// stable in any baseline pose (upright, flat, couch).
  static double rollAngle(double x, double y, double z) =>
      math.atan2(x, math.sqrt(y * y + z * z));

  /// Pitch angle (rad): top-of-device toward/away rotation (gravity swinging
  /// in the device's y–z plane).
  static double pitchAngle(double x, double y, double z) => math.atan2(z, y);

  void startCalibration() {
    _calibrated = false;
    _calRoll.clear();
    _calPitch.clear();
    _roll = 0;
    _pitch = 0;
  }

  /// Feed a sample during calibration. Returns true once enough samples have
  /// been averaged and the baseline is set.
  bool addCalibrationSample(double x, double y, double z) {
    _calRoll.add(rollAngle(x, y, z));
    _calPitch.add(pitchAngle(x, y, z));
    if (_calRoll.length >= tuning.calibrationSamples) {
      _baseRoll = _mean(_calRoll);
      _basePitch = _meanAngle(_calPitch);
      _calibrated = true;
    }
    return _calibrated;
  }

  /// Process one gravity sample into (roll, pitch) input, each ~[-1, 1].
  ({double roll, double pitch}) process(double x, double y, double z) {
    if (!_calibrated) return (roll: 0, pitch: 0);

    final dRoll = rollAngle(x, y, z) - _baseRoll;
    final dPitch = _wrapAngle(pitchAngle(x, y, z) - _basePitch);

    // Low-pass: exponential moving average per sample.
    _roll += tuning.tiltSmoothing * (dRoll - _roll);
    _pitch += tuning.tiltSmoothing * (dPitch - _pitch);

    return (
      roll: _shape(_roll) * tuning.rollSign,
      pitch: _shape(_pitch) * tuning.pitchSign,
    );
  }

  /// Normalise an angle to input space and apply the dead-zone.
  double _shape(double angle) {
    final n = (angle / tuning.tiltMaxAngle).clamp(-1.0, 1.0).toDouble();
    if (n.abs() < tuning.tiltDeadZone) return 0;
    return n;
  }

  static double _mean(List<double> xs) =>
      xs.reduce((a, b) => a + b) / xs.length;

  /// Mean of angles that may straddle the ±π wrap (pitch near face-up poses).
  static double _meanAngle(List<double> xs) {
    var sx = 0.0;
    var sy = 0.0;
    for (final a in xs) {
      sx += math.cos(a);
      sy += math.sin(a);
    }
    return math.atan2(sy, sx);
  }

  static double _wrapAngle(double a) {
    var r = a;
    while (r > math.pi) {
      r -= 2 * math.pi;
    }
    while (r < -math.pi) {
      r += 2 * math.pi;
    }
    return r;
  }
}
