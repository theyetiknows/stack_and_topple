import 'input_event.dart';

/// A port that produces input events for the core to drain each tick.
///
/// Concrete adapters (tap, tilt, test script) live outside the pure core.
/// Draining (pull) rather than streaming (push) keeps the game loop in control
/// of exactly when input is consumed, which keeps stepping deterministic.
abstract interface class InputSource {
  /// Returns and clears all events accumulated since the last drain.
  List<InputEvent> drain();
}
