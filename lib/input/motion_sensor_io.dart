import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'motion_types.dart';

/// Native motion source backed by sensors_plus.
///
/// iOS values are already converted by the plugin to the Android sign
/// convention (m/s^2, gravity included), so both mobile platforms feed the
/// TiltProcessor identically. The plain accelerometer needs no runtime
/// permission on Android or iOS — iOS only requires the
/// NSMotionUsageDescription Info.plist entry.
class MotionSensor {
  StreamController<MotionSample>? _controller;
  StreamSubscription<AccelerometerEvent>? _sub;

  Stream<MotionSample> get samples {
    _controller ??= StreamController<MotionSample>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
    return _controller!.stream;
  }

  void _start() {
    try {
      _sub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (e) => _controller?.add((x: e.x, y: e.y, z: e.z)),
        // A platform without an accelerometer surfaces here: the stream simply
        // stays silent and calibration times out into the graceful fallback.
        onError: (Object _) {},
        cancelOnError: true,
      );
    } catch (_) {
      // Sensor API unavailable (e.g. desktop): emit nothing.
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<bool> requestPermission() async => true;

  void dispose() {
    _stop();
    _controller?.close();
  }
}
