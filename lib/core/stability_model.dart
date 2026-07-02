import 'game_state.dart';
import 'input/input_event.dart';

/// The isolated, swappable heart of the game's *feel*.
///
/// It owns the lean/wobble/topple physics only — NOT the stacking geometry
/// (that lives in [GameLoop]). This split is the documented physics-flexibility
/// seam: the V1 [CustomStabilityModel] can be replaced by a `Forge2DStabilityModel`
/// (real 2D solver) or a future 3D-engine bridge with no change to input,
/// rendering, or state, as long as the same three operations are honoured.
abstract interface class StabilityModel {
  /// Advance lean/wobble by [dt] given the current [balance] input (zero in the
  /// base game). Mutates the lean fields on [state]; sets `state.phase` to
  /// [GamePhase.toppling] if a stability limit is exceeded.
  void integrate(GameState state, double dt, BalanceInput balance);

  /// Register the destabilising effect of a drop, expressed as a signed
  /// misalignment already normalised by platform width.
  void applyDropImpulse(GameState state, double normalizedMisalign);

  /// Drive the falling-over animation while toppling. Returns true when the fall
  /// animation is complete and the run should end.
  bool advanceTopple(GameState state, double dt);
}
