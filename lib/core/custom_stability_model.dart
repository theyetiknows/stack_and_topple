import 'game_state.dart';
import 'input/input_event.dart';
import 'stability_model.dart';

/// V1 stability model: a hand-tuned damped harmonic oscillator on the lean angle.
///
/// Why hand-rolled instead of a physics engine: it gives direct, legible control
/// over exactly the constants we want to tune (wobble, restoring, forgiveness,
/// topple) and — unlike a 2D solver — extends cleanly to the depth axis in
/// Balance Mode. It sits behind [StabilityModel] so a physics-backed variant can
/// be swapped in later.
///
/// Increment A drives only the lateral axis; the depth-axis code paths are
/// present but receive no input until Balance Mode is wired up.
class CustomStabilityModel implements StabilityModel {
  @override
  void integrate(GameState state, double dt, BalanceInput balance) {
    final t = state.tuning;

    // Balance Mode contributes an angular acceleration; zero in the base game.
    final balanceAccelLateral = balance.roll * t.tiltGain;

    // Damped harmonic oscillator:  a = -k*x - c*v (+ balance)
    final accel = -t.restoringStiffness * state.leanLateral -
        t.wobbleDamping * state.leanLateralVel +
        balanceAccelLateral;

    // Semi-implicit Euler (stable for these constants at our fixed dt).
    state.leanLateralVel += accel * dt;
    state.leanLateral += state.leanLateralVel * dt;

    if (state.leanLateral.abs() > t.toppleThreshold) {
      _beginTopple(state, state.leanLateral);
    }
  }

  @override
  void applyDropImpulse(GameState state, double normalizedMisalign) {
    final t = state.tuning;
    // A velocity kick (visible wobble) plus a small static lean offset.
    state.leanLateralVel += normalizedMisalign * t.dropKickGain;
    state.leanLateral += normalizedMisalign * t.leanOffsetGain;
  }

  @override
  bool advanceTopple(GameState state, double dt) {
    final t = state.tuning;
    state.toppleTimer += dt;
    // Accelerate the fall in the chosen direction so it visibly tips over.
    state.leanLateralVel += state.toppleDir * t.toppleFallAccel * dt;
    state.leanLateral += state.leanLateralVel * dt;
    return state.toppleTimer >= t.toppleAnimDuration;
  }

  /// Enter the topple animation, tipping in the direction of the current lean.
  void _beginTopple(GameState state, double leanValue) {
    state.phase = GamePhase.toppling;
    state.toppleTimer = 0;
    final dir = leanValue.sign.toInt(); // double.sign / toInt are built-ins
    state.toppleDir = dir == 0 ? 1 : dir;
  }
}
