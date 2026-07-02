import 'dart:math' as math;

import 'block.dart';
import 'game_state.dart';
import 'input/input_event.dart';
import 'stability_model.dart';

/// Advances the game one fixed step at a time. Owns the *stacking geometry*
/// (sweep, overlap, platform shrink, spawning); delegates all *lean/topple
/// physics* to the injected [StabilityModel]. Pure Dart, deterministic w.r.t.
/// (dt, events) — no Flutter, no rendering, no wall-clock, no randomness.
class GameLoop {
  GameLoop({required this.state, required this.stability});

  final GameState state;
  final StabilityModel stability;

  /// (Re)start a run: reset to a single base block and begin sweeping.
  void startRun() {
    final t = state.tuning;
    state.tower
      ..clear()
      ..add(Block(centerX: 0, width: t.initialBlockWidth, index: 0));
    state.pieceCenterX = -t.sweepHalfRange;
    state.sweepDir = 1;
    state.leanLateral = 0;
    state.leanLateralVel = 0;
    state.leanDepth = 0;
    state.leanDepthVel = 0;
    state.score = 0;
    state.blocksPlaced = 0;
    state.lastDropPerfect = false;
    state.toppleTimer = 0;
    state.toppleDir = 1;
    state.phase = GamePhase.sweeping;
  }

  /// Advance by [dt] seconds, consuming [events] (drops / balance).
  void tick(double dt, List<InputEvent> events) {
    switch (state.phase) {
      case GamePhase.ready:
      case GamePhase.gameOver:
        return;

      case GamePhase.toppling:
        if (stability.advanceTopple(state, dt)) {
          state.phase = GamePhase.gameOver;
        }
        return;

      case GamePhase.sweeping:
        // Resolve drops first, at the piece's current position.
        for (final e in events) {
          if (e is DropEvent && state.phase == GamePhase.sweeping) {
            _performDrop();
          }
        }
        if (state.phase != GamePhase.sweeping) return; // a drop may have toppled
        _advanceSweep(dt);
        stability.integrate(state, dt, _latestBalance(events));
        return;
    }
  }

  BalanceInput _latestBalance(List<InputEvent> events) {
    var balance = const BalanceInput();
    for (final e in events) {
      if (e is BalanceEvent) balance = e.input;
    }
    return balance;
  }

  void _advanceSweep(double dt) {
    final t = state.tuning;
    final speed = math.min(
      t.baseSweepSpeed + t.sweepSpeedPerBlock * state.blocksPlaced,
      t.maxSweepSpeed,
    );
    state.pieceCenterX += state.sweepDir * speed * dt;
    if (state.pieceCenterX > t.sweepHalfRange) {
      state.pieceCenterX = t.sweepHalfRange;
      state.sweepDir = -1;
    } else if (state.pieceCenterX < -t.sweepHalfRange) {
      state.pieceCenterX = -t.sweepHalfRange;
      state.sweepDir = 1;
    }
  }

  void _performDrop() {
    final t = state.tuning;
    final top = state.top;

    final overlapLeft = math.max(state.pieceLeft, top.left);
    final overlapRight = math.min(state.pieceRight, top.right);
    final overlapWidth = overlapRight - overlapLeft;

    // Total miss: the piece doesn't touch the tower at all.
    if (overlapWidth <= 0) {
      state.lastDropPerfect = false;
      _startTopple((state.pieceCenterX - top.centerX).sign.toInt());
      return;
    }

    final misalign = state.pieceCenterX - top.centerX; // signed, world units
    final isPerfect = misalign.abs() <= t.perfectTolerance;

    final double newWidth;
    final double newCenter;
    if (isPerfect) {
      // Reward: keep the full platform and snap to alignment.
      newWidth = top.width;
      newCenter = top.centerX;
      state.score += 1 + t.perfectBonus;
      state.lastDropPerfect = true;
    } else {
      // shrinkFactor blends between "keep full width" (0) and "slice to the
      // overlap" (1) — the forgiveness dial.
      newWidth = top.width - t.shrinkFactor * (top.width - overlapWidth);
      newCenter = (overlapLeft + overlapRight) / 2;
      state.score += 1;
      state.lastDropPerfect = false;
      // Destabilise: normalise by platform width so tighter towers punish harder.
      stability.applyDropImpulse(state, misalign / top.width);
    }

    state.blocksPlaced += 1;
    state.tower.add(Block(
      centerX: newCenter,
      width: newWidth,
      index: top.index + 1,
    ));

    // Structural failure if the platform got too small to build on.
    if (newWidth < t.minPlatformWidth) {
      _startTopple(misalign.sign.toInt());
      return;
    }

    // Spawn the next piece at the left edge, sweeping right.
    state.pieceCenterX = -t.sweepHalfRange;
    state.sweepDir = 1;
  }

  void _startTopple(int dir) {
    state.phase = GamePhase.toppling;
    state.toppleTimer = 0;
    state.toppleDir = dir == 0 ? 1 : dir;
  }
}
