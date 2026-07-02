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

  test('integrate topples when past the threshold', () {
    state.leanLateral = state.tuning.toppleThreshold + 0.05;
    model.integrate(state, 1 / 120, const BalanceInput());
    expect(state.phase, GamePhase.toppling);
    expect(state.toppleDir, 1);
  });

  test('balance roll input drives the lean (Balance Mode wiring)', () {
    state.leanLateral = 0;
    state.leanLateralVel = 0;
    model.integrate(state, 1 / 120, const BalanceInput(roll: 1.0));
    expect(state.leanLateralVel, greaterThan(0));
  });

  test('advanceTopple completes after the animation duration', () {
    state
      ..phase = GamePhase.toppling
      ..toppleDir = 1
      ..toppleTimer = 0;
    var done = false;
    for (var i = 0; i < 1000 && !done; i++) {
      done = model.advanceTopple(state, 1 / 60);
    }
    expect(done, isTrue);
    expect(state.toppleTimer,
        greaterThanOrEqualTo(state.tuning.toppleAnimDuration));
  });
}
