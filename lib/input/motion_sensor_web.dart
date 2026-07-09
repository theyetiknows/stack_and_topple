import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'motion_types.dart';

/// Browser motion source using the DeviceMotion API.
///
/// iOS Safari gates DeviceMotion behind `DeviceMotionEvent.requestPermission()`
/// which may only be called from a user gesture — our calibration tap. Safari
/// also reports accelerationIncludingGravity with the OPPOSITE sign of the
/// Android/Chrome convention; the permission gate only exists on iOS, so its
/// presence doubles as the marker for when to flip signs.
class MotionSensor {
  final StreamController<MotionSample> _controller =
      StreamController.broadcast();
  JSFunction? _listener;
  double _sign = 1;

  Stream<MotionSample> get samples => _controller.stream;

  Future<bool> requestPermission() async {
    final ctor = web.window.getProperty<JSObject?>('DeviceMotionEvent'.toJS);
    if (ctor == null) return false; // API absent (old browser / non-secure)
    final gate = ctor.getProperty<JSFunction?>('requestPermission'.toJS);
    if (gate != null) {
      // iOS/iPadOS Safari path: must run inside a user gesture.
      _sign = -1;
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
      _controller.add((
        x: (g.x ?? 0) * _sign,
        y: (g.y ?? 0) * _sign,
        z: (g.z ?? 0) * _sign,
      ));
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
