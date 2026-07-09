import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/custom_stability_model.dart';
import '../core/game_loop.dart';
import '../core/game_state.dart';
import '../core/tuning.dart';
import '../input/tap_input_source.dart';
import 'tower_renderer.dart';

/// The Flame adapter: it owns the game loop, drives a fixed-timestep tick, and
/// renders the read-only [GameState]. It contains NO game rules — all feel logic
/// lives in the pure-Dart core. Phase/score/level/perfects are exposed as
/// [ValueNotifier]s so Flutter overlays (HUD, start/game-over) can react without
/// polling.
class StackGame extends FlameGame {
  StackGame({TuningConfig? tuning}) : tuning = tuning ?? defaultTuning;

  final TuningConfig tuning;

  late final GameState state = GameState(tuning);
  late final GameLoop loop =
      GameLoop(state: state, stability: CustomStabilityModel());
  final TapInputSource _tap = TapInputSource();

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.ready);
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> level = ValueNotifier(0);
  final ValueNotifier<int> perfectDrops = ValueNotifier(0);

  /// Fixed simulation step — decouples feel from frame rate for determinism.
  static const double _fixedDt = 1 / 120;
  double _accum = 0;
  double _cameraY = 0;
  double _shakePhase = 0; // presentation-only clock for the shake wiggle

  void startRun() {
    loop.startRun();
    _accum = 0;
    _cameraY = 0;
    _syncNotifiers();
  }

  /// Called by the widget layer on a screen tap.
  void onDropTap() {
    if (state.phase == GamePhase.sweeping) _tap.tap();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.phase == GamePhase.ready) {
      _syncNotifiers();
      return;
    }

    _accum += dt;
    if (_accum > 0.25) _accum = 0.25; // clamp to avoid a spiral of death

    // Deliver this frame's taps only to the first sub-step, so a drop resolves
    // once at the piece's current position.
    final events = _tap.drain();
    var firstStep = true;
    while (_accum >= _fixedDt) {
      loop.tick(_fixedDt, firstStep ? events : const []);
      _accum -= _fixedDt;
      firstStep = false;
    }

    // Smoothly follow the top of the tower (exponential ease, frame-rate safe).
    final targetY = (state.blocksPlaced + 1) * tuning.blockHeight;
    _cameraY += (targetY - _cameraY) * (1 - math.exp(-dt * 6.0));

    _shakePhase += dt;
    _syncNotifiers();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;

    // Impact shake: a small decaying wiggle after sloppy drops. Purely a canvas
    // translation — the simulation never sees it.
    canvas.save();
    if (state.impactShakeTimer > 0) {
      final p = state.impactShakeTimer / tuning.impactShakeDuration;
      final mag = 5.0 * p;
      canvas.translate(
        math.sin(_shakePhase * 70) * mag,
        math.cos(_shakePhase * 63) * mag * 0.6,
      );
    }
    TowerPainter(
      state: state,
      tuning: tuning,
      cameraY: _cameraY,
      width: size.x,
      height: size.y,
    ).paint(canvas);
    canvas.restore();
  }

  void _syncNotifiers() {
    if (phase.value != state.phase) phase.value = state.phase;
    if (score.value != state.score) score.value = state.score;
    if (level.value != state.level) level.value = state.level;
    if (perfectDrops.value != state.perfectDrops) {
      perfectDrops.value = state.perfectDrops;
    }
  }

  @override
  void onRemove() {
    phase.dispose();
    score.dispose();
    level.dispose();
    perfectDrops.dispose();
    super.onRemove();
  }
}
