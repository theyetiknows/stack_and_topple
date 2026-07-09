import 'dart:async';

import '../core/input/input_event.dart';
import '../core/input/input_source.dart';
import '../core/input/tilt_processor.dart';
import '../core/tuning.dart';
import 'motion_sensor.dart';
import 'motion_types.dart';

/// Bridges the platform motion sensor to the core's source-agnostic
/// [BalanceEvent]s: permission → calibration ("hold comfortably, tap when
/// steady") → per-sample processing. The game loop drains the queued events
/// each tick and HOLDS the last value between samples, so a ~50 Hz sensor
/// drives the 120 Hz sim smoothly.
class TiltInputSource implements InputSource {
  TiltInputSource(TuningConfig tuning) : _processor = TiltProcessor(tuning);

  final TiltProcessor _processor;
  final MotionSensor _sensor = MotionSensor();
  final List<InputEvent> _queue = [];
  StreamSubscription<MotionSample>? _sub;

  /// Ask for sensor access. On iOS Safari this MUST run inside a user gesture
  /// (we call it from the calibration tap). False = unavailable or denied.
  Future<bool> requestPermission() => _sensor.requestPermission();

  /// Capture the player's current pose as the neutral baseline. Resolves true
  /// once enough samples arrived; false on [timeout] (no sensor data flowing —
  /// e.g. desktop browsers), which the UI turns into a graceful fallback.
  Future<bool> calibrate({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _processor.startCalibration();
    final done = Completer<bool>();
    late final StreamSubscription<MotionSample> calSub;
    calSub = _sensor.samples.listen((s) {
      if (_processor.addCalibrationSample(s.x, s.y, s.z) &&
          !done.isCompleted) {
        done.complete(true);
      }
    });
    final ok = await done.future.timeout(timeout, onTimeout: () => false);
    await calSub.cancel();
    if (ok) _listen();
    return ok;
  }

  void _listen() {
    _sub ??= _sensor.samples.listen((s) {
      final out = _processor.process(s.x, s.y, s.z);
      _queue.add(BalanceEvent(BalanceInput(roll: out.roll, pitch: out.pitch)));
      // The loop drains every frame; cap defensively so a paused frame can't
      // let the queue grow without bound.
      if (_queue.length > 512) _queue.removeAt(0);
    });
  }

  @override
  List<InputEvent> drain() {
    if (_queue.isEmpty) return const <InputEvent>[];
    final out = List<InputEvent>.of(_queue);
    _queue.clear();
    return out;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _sensor.dispose();
  }
}
