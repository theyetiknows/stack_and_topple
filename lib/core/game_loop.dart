import 'dart:math' as math;

import 'block.dart';
import 'debris.dart';
import 'game_state.dart';
import 'input/input_event.dart';
import 'stability_model.dart';

/// Advances the game one fixed step at a time. Owns the *stacking geometry*
/// (sweep, overlap slicing, debris, spawning); delegates all *lean/topple
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
    state.debris.clear();
    state.pieceCenterX = -t.sweepHalfRange;
    state.sweepDir = 1;
    state.leanLateral = 0;
    state.leanLateralVel = 0;
    state.leanDepth = 0;
    state.leanDepthVel = 0;
    state.score = 0;
    state.blocksPlaced = 0;
    state.perfectDrops = 0;
    state.lastDropPerfect = false;
    state.perfectFlashTimer = 0;
    state.dropBounceTimer = 0;
    state.impactShakeTimer = 0;
    state.toppleTimer = 0;
    state.toppleDir = 1;
    state.endTimer = 0;
    state.phase = GamePhase.sweeping;
  }

  /// Advance by [dt] seconds, consuming [events] (drops / balance).
  void tick(double dt, List<InputEvent> events) {
    // Debris and feedback timers animate in every phase (they are cosmetic and
    // must keep moving while a miss falls or the game-over card appears).
    _updateDebris(dt);
    _decayTimers(dt);

    switch (state.phase) {
      case GamePhase.ready:
      case GamePhase.gameOver:
        return;

      case GamePhase.ending:
        state.endTimer -= dt;
        if (state.endTimer <= 0) state.phase = GamePhase.gameOver;
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
        if (state.phase != GamePhase.sweeping) return; // drop ended the run
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
    state.pieceCenterX += state.sweepDir * state.currentSweepSpeed * dt;
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
    final pieceHeight = t.blockHeight;
    // The dropped piece lands on top of the current stack surface.
    final landBottomY = (top.index + 1) * t.blockHeight;

    final overlapLeft = math.max(state.pieceLeft, top.left);
    final overlapRight = math.min(state.pieceRight, top.right);
    final overlapWidth = overlapRight - overlapLeft;

    // Total miss: the whole piece sails past the tower and falls away.
    if (overlapWidth <= 0) {
      state.lastDropPerfect = false;
      final side = (state.pieceCenterX - top.centerX).sign;
      state.debris.add(Debris(
        centerX: state.pieceCenterX,
        bottomY: landBottomY,
        width: state.pieceWidth,
        height: pieceHeight,
        vx: side * t.debrisKickVx,
        vy: 0,
        angVel: side * t.debrisSpin,
      ));
      state.impactShakeTimer = t.impactShakeDuration;
      state.phase = GamePhase.ending;
      state.endTimer = t.missEndDelay;
      return;
    }

    final misalign = state.pieceCenterX - top.centerX; // signed, world units
    final isPerfect = misalign.abs() <= t.perfectTolerance;

    final double newWidth;
    final double newCenter;
    if (isPerfect) {
      // Reward: no slice, keep the full platform and snap to alignment.
      newWidth = top.width;
      newCenter = top.centerX;
      state.score += 1 + t.perfectBonus;
      state.perfectDrops += 1;
      state.lastDropPerfect = true;
      state.perfectFlashTimer = t.perfectFlashDuration;
    } else {
      // Slice to the EXACT overlap: the kept part stays precisely where the
      // piece landed, and the overhang breaks off as visible falling debris —
      // so the cut always lines up with what the player saw.
      newWidth = overlapWidth;
      newCenter = (overlapLeft + overlapRight) / 2;
      state.score += 1;
      state.lastDropPerfect = false;

      final overhangRight = misalign > 0;
      final double debrisLeft = overhangRight ? overlapRight : state.pieceLeft;
      final double debrisRight = overhangRight ? state.pieceRight : overlapLeft;
      final side = overhangRight ? 1.0 : -1.0;
      state.debris.add(Debris(
        centerX: (debrisLeft + debrisRight) / 2,
        bottomY: landBottomY,
        width: debrisRight - debrisLeft,
        height: pieceHeight,
        vx: side * t.debrisKickVx,
        vy: 0,
        angVel: side * t.debrisSpin,
      ));

      // Destabilise: normalise by platform width so tighter towers punish harder.
      stability.applyDropImpulse(state, misalign / top.width);
      state.impactShakeTimer = t.impactShakeDuration;
    }

    state.blocksPlaced += 1;
    state.dropBounceTimer = t.dropBounceDuration;
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

  void _updateDebris(double dt) {
    final t = state.tuning;
    for (final d in state.debris) {
      d.age += dt;
      d.vy -= t.debrisGravity * dt; // world Y is up; gravity pulls down
      d.bottomY += d.vy * dt;
      d.centerX += d.vx * dt;
      d.rotation += d.angVel * dt;
    }
    state.debris.removeWhere((d) => d.age > t.debrisLifetime);
  }

  void _decayTimers(double dt) {
    if (state.perfectFlashTimer > 0) state.perfectFlashTimer -= dt;
    if (state.dropBounceTimer > 0) state.dropBounceTimer -= dt;
    if (state.impactShakeTimer > 0) state.impactShakeTimer -= dt;
  }

  void _startTopple(int dir) {
    state.phase = GamePhase.toppling;
    state.toppleTimer = 0;
    state.toppleDir = dir == 0 ? 1 : dir;
  }
}
