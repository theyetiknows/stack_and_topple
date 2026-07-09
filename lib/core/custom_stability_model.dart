import 'game_state.dart';
import 'input/input_event.dart';
import 'stability_model.dart';

/// V1 stability model: a hand-tuned damped harmonic oscillator on the lean
/// angle, run independently per axis.
///
/// Why hand-rolled instead of a physics engine: it gives direct, legible
/// control over exactly the constants we want to tune (wobble, restoring,
/// forgiveness) and — unlike a 2D solver — extends cleanly to the depth axis.
/// It sits behind [StabilityModel] so a physics-backed variant can swap in.
///
/// Axis roles: drops attack ONLY the lateral axis; the depth axis is
/// threatened (and defended) purely by tilt, so it is live only while Balance
/// Mode is active. Topple/save RULES live in GameLoop — this class never
/// changes the phase.
class CustomStabilityModel implements StabilityModel {
  @override
  void integrate(GameState state, double dt, BalanceInput balance) {
    final t = state.tuning;
    final active = state.balanceModeActive;

    // Balance Mode deliberately weakens the self-righting spring so the
    // player's hand becomes the main stabilising force.
    final k = t.restoringStiffness * (active ? t.balanceStiffnessFactor : 1);
    final c = t.wobbleDamping * (active ? t.balanceDampingFactor : 1);

    // Tilt SHIFTS THE EQUILIBRIUM the spring pulls toward (tilting the phone
    // commands a lean), rather than adding a force. This is what makes both
    // halves of the spec true at once: holding a too-far tilt drives the lean
    // past the topple threshold, and counter-tilting pulls a leaning tower
    // back toward upright.
    final rollTarget = active ? balance.roll * t.tiltLeanTarget : 0.0;
    final ax =
        -k * (state.leanLateral - rollTarget) - c * state.leanLateralVel;
    // Semi-implicit Euler (stable for these constants at our fixed dt).
    state.leanLateralVel += ax * dt;
    state.leanLateral += state.leanLateralVel * dt;

    // Depth axis: same oscillator, gentler target, only while active.
    if (active) {
      final pitchTarget = balance.pitch * t.tiltLeanTargetPitch;
      final az =
          -k * (state.leanDepth - pitchTarget) - c * state.leanDepthVel;
      state.leanDepthVel += az * dt;
      state.leanDepth += state.leanDepthVel * dt;
    }
  }

  @override
  void applyDropImpulse(GameState state, double normalizedMisalign) {
    final t = state.tuning;
    // A velocity kick (visible wobble) plus a small static lean offset.
    // Drops only ever attack the lateral axis — by design.
    state.leanLateralVel += normalizedMisalign * t.dropKickGain;
    state.leanLateral += normalizedMisalign * t.leanOffsetGain;
  }
}
