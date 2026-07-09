import 'package:flutter_test/flutter_test.dart';
import 'package:stack_and_topple/core/custom_stability_model.dart';
import 'package:stack_and_topple/core/game_state.dart';
import 'package:stack_and_topple/core/input/input_event.dart';
import 'package:stack_and_topple/core/tuning.dart';

void main() {
  late GameState state;
  late CustomStabilityModel model;

  setUp(() {
    state = GameState(const TuningConfig())..phase = GamePhase.sweeping;
    model = CustomStabilityModel();
  });

  test('applyDropImpulse kicks velocity and lean in the misalign direction', () {
    model.applyDropImpulse(state, 0.3);
    expect(state.leanLateralVel, greaterThan(0));
    expect(state.leanLateral, greaterThan(0));

    final negative = GameState(const TuningConfig());
    model.applyDropImpulse(negative, -0.3);
    expect(negative.leanLateralVel, lessThan(0));
    expect(negative.leanLateral, lessThan(0));
  });

  test('integrate applies a restoring force toward upright', () {
    state.leanLateral = 0.1;
    state.leanLateralVel = 0;
    model.integrate(state, 1 / 120, const BalanceInput());
    expect(state.leanLateralVel, lessThan(0)); // pushed back toward 0
  });

  test('integrate never changes the phase (rules live in the loop)', () {
    state.leanLateral = state.tuning.toppleThreshold + 1.0;
    model.integrate(state, 1 / 120, const BalanceInput());
    expect(state.phase, GamePhase.sweeping);
    expect(state.leanMagnitude, greaterThan(state.tuning.toppleThreshold));
  });

  test('balance roll drives the lateral lean only when Balance Mode is active',
      () {
    // Inactive: tilt input must be completely inert.
    model.integrate(state, 1 / 120, const BalanceInput(roll: 1.0));
    expect(state.leanLateralVel, 0);

    // Active: the same input pushes the tower.
    state.balanceModeActive = true;
    model.integrate(state, 1 / 120, const BalanceInput(roll: 1.0));
    expect(state.leanLateralVel, greaterThan(0));
  });

  test('holding full tilt drives the lean PAST the topple threshold', () {
    // The spec: tilting too far past neutral topples the tower. The
    // equilibrium the spring is pulled toward at full input (tiltLeanTarget)
    // must therefore sit beyond the threshold.
    state.balanceModeActive = true;
    expect(state.tuning.tiltLeanTarget,
        greaterThan(state.tuning.toppleThreshold));
    for (var i = 0; i < 2400; i++) {
      model.integrate(state, 1 / 120, const BalanceInput(roll: 1.0));
    }
    expect(state.leanLateral, greaterThan(state.tuning.toppleThreshold));
  });

  test('pitch reaches past the threshold on the depth axis too', () {
    state.balanceModeActive = true;
    expect(state.tuning.tiltLeanTargetPitch,
        greaterThan(state.tuning.toppleThreshold));
    for (var i = 0; i < 2400; i++) {
      model.integrate(state, 1 / 120, const BalanceInput(pitch: 1.0));
    }
    expect(state.leanDepth, greaterThan(state.tuning.toppleThreshold));
    expect(state.leanLateral.abs(), lessThan(state.leanDepth));
  });

  test('counter-tilt pulls a leaning tower back toward upright', () {
    state.balanceModeActive = true;
    state.leanLateral = 0.3; // badly leaning right
    for (var i = 0; i < 240; i++) {
      model.integrate(state, 1 / 120, const BalanceInput(roll: -0.6));
    }
    expect(state.leanLateral, lessThan(0.1)); // rescued leftward
  });

  test('depth axis stays exactly zero with Balance Mode off', () {
    for (var i = 0; i < 1000; i++) {
      model.integrate(state, 1 / 120, const BalanceInput(pitch: 1.0));
    }
    expect(state.leanDepth, 0);
    expect(state.leanDepthVel, 0);
  });
}
