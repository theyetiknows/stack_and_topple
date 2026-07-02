/// Source-agnostic input events consumed by the game core.
///
/// The core never knows whether an event came from a tap, from tilt, or from a
/// test script — that decoupling is what lets Balance Mode be a toggle (attach a
/// tilt source) rather than a code fork, and lets tests drive the exact same
/// code path a real player does.
library;

sealed class InputEvent {
  const InputEvent();
}

/// The player commits the currently-sweeping piece.
class DropEvent extends InputEvent {
  const DropEvent();
}

/// A continuous balance adjustment (Balance Mode). In the base game no
/// [BalanceEvent]s are emitted, so the depth axis stays dormant.
class BalanceEvent extends InputEvent {
  final BalanceInput input;
  const BalanceEvent(this.input);
}

/// A processed, calibrated balance reading. Components are roughly in [-1, 1].
///   - [roll]  drives the lateral lean (Lx): tilt left/right.
///   - [pitch] drives the depth lean   (Lz): tilt toward/away (Balance Mode only).
class BalanceInput {
  final double roll;
  final double pitch;
  const BalanceInput({this.roll = 0, this.pitch = 0});
}
