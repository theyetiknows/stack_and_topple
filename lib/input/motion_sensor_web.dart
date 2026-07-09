import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'motion_types.dart';

/// Browser motion source using the DeviceMotion API.
///
/// iOS Safari gates DeviceMotion behind `DeviceMotionEvent.requestPermission()`
/// which may only be called from a user gesture — our calibration tap.
/// Empirically (iPhone playtest 2026-07) Safari's accelerationIncludingGravity
/// matches the standard convention, so NO sign flip is applied here; per-axis
/// quirks on other devices are handled by rollSign/pitchSign in TuningConfig.
class MotionSensor {
  final StreamController<MotionSample> _controller =
      StreamController.broadcast();
  JSFunction? _listener;

  Stream<MotionSample> get samples => _controller.stream;

  Future<bool> requestPermission() async {
    final ctor = web.window.getProperty<JSObject?>('DeviceMotionEvent'.toJS);
    if (ctor == null) return false; // API absent (old browser / non-secure)
    final gate = ctor.getProperty<JSFunction?>('requestPermission'.toJS);
    if (gate != null) {
      // iOS/iPadOS Safari path: must run inside a user gesture.
      try {
        final result =
            await (gate.callAsFunction(ctor)! as JSPromise<JSAny?>).toDart;
        if ((result.dartify() as String?) != 'granted') return false;
      } catch (_) {
        return false; // not a gesture / dismissed → treat as denied
      }
    }
    _attach();
    return true;
  }

  void _attach() {
    if (_listener != null) return;
    void onMotion(web.Event e) {
      final g = (e as web.DeviceMotionEvent).accelerationIncludingGravity;
      if (g == null) return;
      _controller.add((x: g.x ?? 0, y: g.y ?? 0, z: g.z ?? 0));
    }

    _listener = onMotion.toJS;
    web.window.addEventListener('devicemotion', _listener);
  }

  void dispose() {
    if (_listener != null) {
      web.window.removeEventListener('devicemotion', _listener);
      _listener = null;
    }
    _controller.close();
  }
}
