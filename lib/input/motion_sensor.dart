/// Platform-conditional motion sensor.
///
/// Exposes a single `MotionSensor` class with the same API everywhere:
///   - `samples`: a `Stream<MotionSample>` of gravity-included accelerometer
///     readings
///   - `requestPermission()`: resolves false when motion is unavailable/denied
///   - `dispose()`
///
/// The io implementation wraps sensors_plus (Android/iOS); the web one wraps
/// the browser DeviceMotion API (including iOS Safari's user-gesture
/// permission dance). The TiltProcessor downstream is platform-blind.
library;

export 'motion_sensor_io.dart'
    if (dart.library.js_interop) 'motion_sensor_web.dart';
