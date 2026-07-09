import 'game_state.dart';
import 'input/input_event.dart';

/// The isolated, swappable heart of the game's *feel*.
///
/// It owns the lean/wobble DYNAMICS only — NOT the stacking geometry and not
/// the topple/save RULES (those live in [GameLoop], which reads
/// `state.leanMagnitude` after integration). This split is the documented
/// physics-flexibility seam: the V1 [CustomStabilityModel] can be replaced by
/// a `Forge2DStabilityModel` (real 2D solver) or a future 3D-engine bridge
/// with no change to input, rendering, state, or rules, as long as the same
/// two operations are honoured.
abstract interface class StabilityModel {
  /// Advance the lean state by [dt] given the current [balance] input (zero
  /// in the base game). Mutates only the lean fields on [state].
  void integrate(GameState state, double dt, BalanceInput balance);

  /// Register the destabilising effect of a drop, expressed as a signed
  /// misalignment already normalised by platform width.
  void applyDropImpulse(GameState state, double normalizedMisalign);
}
