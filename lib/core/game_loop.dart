import 'dart:math' as math;

import 'block.dart';
import 'debris.dart';
import 'game_state.dart';
import 'input/input_event.dart';
import 'stability_model.dart';

/// Advances the game one fixed step at a time. Owns the *stacking geometry*
/// and the *topple/save rules* (sweep, overlap slicing, debris, shedding,
/// the SAVE window, collapse, scoring); delegates the lean/wobble *dynamics*
/// to the injected [StabilityModel]. Pure Dart, deterministic w.r.t.
/// (dt, events) — no Flutter, no rendering, no wall-clock, no randomness
/// (per-block variation uses an index hash).
class GameLoop {
  GameLoop({required this.state, required this.stability});

  final GameState state;
  final StabilityModel stability;

  /// (Re)start a run: reset to a single base block and begin sweeping.
  /// [balanceMode] arms the depth axis, the tilt→lean coupling, and saves.
  /// [looseStack] additionally un-welds the stack so blocks shear under lean
  /// (requires [balanceMode]; it is the tilt that drives the shear).
  /// [seed] drives the core RNG (spawn-side variety); the adapter passes
  /// wall-clock entropy, tests pass constants — the core itself stays
  /// deterministic w.r.t. (seed, dt, events).
  void startRun({
    bool balanceMode = false,
    bool looseStack = false,
    int seed = 1,
  }) {
    final t = state.tuning;
    state.tower
      ..clear()
      ..add(Block(centerX: 0, width: t.initialBlockWidth, index: 0));
    state.debris.clear();
    state.rngState = (seed & 0x7fffffff) | 1; // never zero
    state.sweepCenterX = 0;
    state.looseStackActive = looseStack && balanceMode;
    _spawnPiece();
    state.leanLateral = 0;
    state.leanLateralVel = 0;
    state.leanDepth = 0;
    state.leanDepthVel = 0;
    state.balanceModeActive = balanceMode;
    state.currentRoll = 0;
    state.currentPitch = 0;
    state.score = 0;
    state.blocksPlaced = 0;
    state.perfectDrops = 0;
    state.lastDropPerfect = false;
    state.perfectFlashTimer = 0;
    state.dropBounceTimer = 0;
    state.impactShakeTimer = 0;
    state.collapseTimer = 0;
    state.saveWindowTimer = 0;
    state.saveDwellTimer = 0;
    state.saves = 0;
    state.blocksLost = 0;
    state.highestLevelAwarded = 0;
    state.endTimer = 0;
    state.phase = GamePhase.sweeping;
  }

  /// Advance by [dt] seconds, consuming [events] (drops / balance).
  void tick(double dt, List<InputEvent> events) {
    // Debris and feedback timers animate in every phase (they are cosmetic and
    // must keep moving while a collapse plays or the game-over card appears).
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
        // The jumble is already flying (debris updates above); this phase just
        // holds the camera on the wreckage before the game-over card.
        state.collapseTimer += dt;
        if (state.collapseTimer >= state.tuning.collapseDuration) {
          state.phase = GamePhase.gameOver;
        }
        return;

      case GamePhase.critical:
        _tickCritical(dt, events);
        return;

      case GamePhase.sweeping:
        // Consume input: drops resolve immediately at the piece's current
        // position; balance readings are HELD on the state until the next
        // reading arrives (sensor rate < sim rate).
        for (final e in events) {
          switch (e) {
            case DropEvent():
              if (state.phase == GamePhase.sweeping) _performDrop();
            case BalanceEvent(:final input):
              state.currentRoll = input.roll;
              state.currentPitch = input.pitch;
          }
        }
        if (state.phase != GamePhase.sweeping) return; // drop ended the run
        _advanceSweep(dt);
        stability.integrate(
          state,
          dt,
          BalanceInput(roll: state.currentRoll, pitch: state.currentPitch),
        );
        if (state.looseStackActive) {
          // Erode-only failure model: the tower never topples outright. The
          // lean is held at the wall and the damage arrives as blocks shearing
          // off the top — the run ends when nothing is left but the base.
          _softWallLean();
          _updateSlide(dt);
        } else if (state.leanMagnitude > state.tuning.toppleThreshold) {
          _onUnstable();
        }
        return;
    }
  }

  /// The SAVE window: the tower is critically leaning; the player fights with
  /// tilt. The lean is SOFT-WALLED just inside the threshold for the whole
  /// window — the natural panic overcorrection (which swings the lean toward
  /// the far side) can no longer insta-kill the run. The save is decided
  /// purely by: hold the lean inside the safe zone for [saveDwell] seconds
  /// before the window expires; otherwise the tower collapses.
  void _tickCritical(double dt, List<InputEvent> events) {
    final t = state.tuning;
    for (final e in events) {
      if (e is BalanceEvent) {
        state.currentRoll = e.input.roll;
        state.currentPitch = e.input.pitch;
      }
      // Drops are ignored: there is no active piece while fighting the save.
    }
    stability.integrate(
      state,
      dt,
      BalanceInput(roll: state.currentRoll, pitch: state.currentPitch),
    );
    state.saveWindowTimer -= dt;

    _softWallLean();

    // Steady-inside-the-zone wins; merely swinging through centre does not.
    if (state.leanMagnitude < t.toppleThreshold * t.saveRecoveryFactor) {
      state.saveDwellTimer += dt;
      if (state.saveDwellTimer >= t.saveDwell) {
        _saveSuccess();
        return;
      }
    } else {
      state.saveDwellTimer = 0;
    }

    if (state.saveWindowTimer <= 0) {
      _fullCollapse();
    }
  }

  /// Hold the lean just inside the topple threshold: rescale the (Lx, Lz)
  /// vector back to the wall and bleed velocity, so the tower strains against
  /// the edge instead of tipping over it. Shared by the SAVE window and Loose
  /// Stack, which both need a leaning-but-not-toppling tower.
  void _softWallLean() {
    final t = state.tuning;
    // Loose Stack never topples, so its wall is a separate, lower angle: it
    // bounds how far a tall tower can visually swing off-centre while the
    // player leans on it indefinitely.
    final wall = state.looseStackActive
        ? t.looseLeanWall
        : t.toppleThreshold * 0.99;
    final mag = state.leanMagnitude;
    if (mag <= wall) return;
    final scale = wall / mag;
    state.leanLateral *= scale;
    state.leanDepth *= scale;
    state.leanLateralVel *= 0.5;
    state.leanDepthVel *= 0.5;
  }

  /// Loose Stack: slide each interface that the lean has overcome, then drop
  /// any block that has lost its footing.
  ///
  /// Each block's slide velocity is RELATIVE to the block beneath it, and the
  /// displacements accumulate up the stack (a block is carried by everything
  /// sliding below it) — that running sum is what produces the deck-of-cards
  /// shear instead of blocks drifting independently.
  void _updateSlide(double dt) {
    final t = state.tuning;
    final lean = state.leanLateral;
    final mag = lean.abs();
    final dir = lean.sign;
    final damp = (1 - t.slideDamping * dt).clamp(0.0, 1.0);

    var carried = 0.0; // displacement inherited from every interface below
    for (var i = 1; i < state.tower.length; i++) {
      final b = state.tower[i];
      // Load above this interface pins it: the top of the stack goes first.
      final above = state.tower.length - 1 - i;
      final grip =
          math.min(t.slipAngle + t.gripPerBlockAbove * above, t.maxGripAngle);
      final excess = mag - grip;
      if (excess > 0) {
        b.slideVel += dir * t.slideAccelGain * excess * dt;
      }
      b.slideVel *= damp;
      carried += b.slideVel * dt;
      b.centerX += carried;
    }

    _checkSupport();
  }

  /// Bottom-up scan for the first interface that can no longer hold what is
  /// stacked on it. Two ways to fail, checked at every interface:
  ///
  ///  1. *Footing* — the block barely overlaps its support any more.
  ///  2. *Balance* — the combined centre of mass of everything ABOVE the
  ///     interface has passed outside the contact patch it rests on.
  ///
  /// The second is the one that matters: shear accumulates up the stack, so
  /// each individual interface can look perfectly healthy while the upper
  /// section as a whole has toppled well past its footing. Without this the
  /// tower slides arbitrarily far sideways and simply leaves the screen.
  void _checkSupport() {
    final t = state.tuning;
    for (var i = 1; i < state.tower.length; i++) {
      final b = state.tower[i];
      final below = state.tower[i - 1];

      final contactLeft = math.max(b.left, below.left);
      final contactRight = math.min(b.right, below.right);
      if (contactRight - contactLeft < b.width * t.minSupportFraction) {
        _shearFrom(i);
        return;
      }

      // Centre of mass of blocks i..top (equal mass per block).
      var sum = 0.0;
      for (var k = i; k < state.tower.length; k++) {
        sum += state.tower[k].centerX;
      }
      final com = sum / (state.tower.length - i);
      if (com < contactLeft || com > contactRight) {
        _shearFrom(i);
        return;
      }
    }
  }

  /// Drop `tower[from..]` as tumbling debris: the Loose Stack damage event.
  /// Charges the fallen-block penalty per block and ends the run if the tower
  /// is stripped back to the bare base.
  void _shearFrom(int from) {
    final t = state.tuning;
    final dir = state.leanLateral == 0 ? 1.0 : state.leanLateral.sign;
    final count = state.tower.length - from;
    if (count <= 0) return;

    while (state.tower.length > from) {
      _blockToDebris(state.tower.removeLast(), dir);
    }
    state.score = math.max(0, state.score - t.fallenBlockPenalty * count);
    state.blocksLost += count;
    state.blocksPlaced = state.tower.length - 1;
    state.impactShakeTimer = t.impactShakeDuration;

    // Everything the player built is gone: that is "the whole tower fell".
    if (state.tower.length <= 1) {
      state.leanLateral = 0;
      state.leanLateralVel = 0;
      state.leanDepth = 0;
      state.leanDepthVel = 0;
      state.collapseTimer = 0;
      state.phase = GamePhase.toppling;
      return;
    }

    // The new top block keeps whatever shear it already had, but the shock
    // kills the slide momentum of what survives.
    for (final b in state.tower) {
      b.slideVel = 0;
    }
  }

  /// The lean crossed the threshold during play. Balance Mode gets a chance
  /// to save a shorter tower; classic mode (or a too-short tower) collapses.
  void _onUnstable() {
    final t = state.tuning;
    final aboveBase = state.tower.length - 1;
    final shedCount = math.max(1, (aboveBase * t.shedFraction).round());
    final remaining = state.tower.length - shedCount;

    if (!state.balanceModeActive || remaining < 2) {
      _fullCollapse();
      return;
    }

    _shedTopBlocks(shedCount);

    // Clamp the lean back just inside the threshold (still critical, but
    // physically saveable) and bleed off most of the angular velocity.
    final scale =
        (t.criticalLeanFactor * t.toppleThreshold) / state.leanMagnitude;
    state.leanLateral *= scale;
    state.leanDepth *= scale;
    state.leanLateralVel *= 0.3;
    state.leanDepthVel *= 0.3;

    state.blocksPlaced = state.tower.length - 1;
    state.saveWindowTimer = t.saveWindow;
    state.saveDwellTimer = 0;
    state.impactShakeTimer = t.impactShakeDuration;
    state.phase = GamePhase.critical;
  }

  void _saveSuccess() {
    state.score += state.tuning.saveBonus;
    state.saves += 1;
    // Resume building from the lower height.
    _spawnPiece();
    state.phase = GamePhase.sweeping;
  }

  /// Convert every block above the base into individually tumbling debris —
  /// the Jenga-style jumble — and end the run after a beat.
  void _fullCollapse() {
    final dir = state.leanLateral == 0 ? 1.0 : state.leanLateral.sign;
    while (state.tower.length > 1) {
      _blockToDebris(state.tower.removeLast(), dir);
    }
    state.blocksPlaced = 0;
    // The surviving base sits flat; zero the lean so nothing renders askew.
    state.leanLateral = 0;
    state.leanLateralVel = 0;
    state.leanDepth = 0;
    state.leanDepthVel = 0;
    state.collapseTimer = 0;
    state.impactShakeTimer = state.tuning.impactShakeDuration;
    state.phase = GamePhase.toppling;
  }

  /// Shed the top [count] blocks as tumbling debris, charging the
  /// fallen-block penalty for each.
  void _shedTopBlocks(int count) {
    final t = state.tuning;
    final dir = state.leanLateral == 0 ? 1.0 : state.leanLateral.sign;
    for (var i = 0; i < count && state.tower.length > 1; i++) {
      _blockToDebris(state.tower.removeLast(), dir);
    }
    state.score = math.max(0, state.score - t.fallenBlockPenalty * count);
  }

  /// Turn a tower block into debris with velocities that fan out in the fall
  /// direction. Variation comes from a deterministic index hash — never from
  /// wall-clock randomness — so replays stay reproducible.
  void _blockToDebris(Block b, double dir) {
    final t = state.tuning;
    final h1 = _hash(b.index);
    final h2 = _hash(b.index + 101);
    final h3 = _hash(b.index + 419);
    state.debris.add(Debris(
      centerX: b.centerX,
      bottomY: b.index * t.blockHeight,
      width: b.width,
      height: t.blockHeight,
      vx: dir * (1.2 + 2.4 * h1) + (h2 - 0.5) * 1.6,
      vy: 0.8 + 2.2 * h2, // small upward pop before gravity wins
      angVel: dir * (1.2 + 2.8 * h3) * (h1 > 0.5 ? 1 : -1),
      colorIndex: b.index, // fallen blocks keep their stacked colour
    ));
  }

  /// Cheap deterministic hash → [0, 1).
  static double _hash(int i) =>
      ((i * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

  void _advanceSweep(double dt) {
    final t = state.tuning;
    final hi = state.sweepCenterX + t.sweepHalfRange;
    final lo = state.sweepCenterX - t.sweepHalfRange;
    state.pieceCenterX += state.sweepDir * state.currentSweepSpeed * dt;
    if (state.pieceCenterX > hi) {
      state.pieceCenterX = hi;
      state.sweepDir = -1;
    } else if (state.pieceCenterX < lo) {
      state.pieceCenterX = lo;
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
        colorIndex: top.index + 1,
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
        colorIndex: top.index + 1,
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

    // One-time bonus for reaching a new difficulty level (highest-awarded
    // tracking means shedding and re-climbing cannot farm it).
    if (state.level > state.highestLevelAwarded) {
      state.highestLevelAwarded = state.level;
      state.score += t.levelBonus;
    }

    // Structural failure if the platform got too small to build on.
    if (newWidth < t.minPlatformWidth) {
      _fullCollapse();
      return;
    }

    _spawnPiece();
  }

  /// Spawn the next sweeping piece from a random side (seeded RNG), entering
  /// at the chosen edge and sweeping inward.
  void _spawnPiece() {
    // Loose Stack lets the tower shear sideways, so the sweep has to travel
    // with it — a fixed range centred on the origin would leave a drifted top
    // block barely reachable at the very end of the sweep, or not at all.
    state.sweepCenterX =
        state.looseStackActive && state.tower.isNotEmpty ? state.top.centerX : 0;
    state.sweepDir = _nextRand() < 0.5 ? 1 : -1;
    state.pieceCenterX =
        state.sweepCenterX - state.sweepDir * state.tuning.sweepHalfRange;
  }

  /// Core-side LCG in [0, 1); advances [GameState.rngState]. High bits only
  /// (the division), so the classic LCG low-bit weakness never shows.
  double _nextRand() {
    state.rngState = (state.rngState * 1103515245 + 12345) & 0x7fffffff;
    return state.rngState / 0x7fffffff;
  }

  void _updateDebris(double dt) {
    final t = state.tuning;
    for (final d in state.debris) {
      d.age += dt;
      d.vy -= t.debrisGravity * dt; // world Y is up; gravity pulls down
      d.bottomY += d.vy * dt;
      d.centerX += d.vx * dt;
      d.rotation += d.angVel * dt;

      // Ground plane at y=0: bounce once or twice, then settle into the pile
      // (this is what makes a collapse read as "fallen on the ground" rather
      // than blocks sailing forever).
      if (d.bottomY <= 0 && d.vy < 0) {
        d.bottomY = 0;
        if (d.vy < -2.0) {
          d.vy = -d.vy * t.debrisRestitution;
        } else {
          d.vy = 0;
        }
        d.vx *= t.debrisGroundFriction;
        d.angVel *= 0.5;
      }
    }
    state.debris.removeWhere((d) => d.age > t.debrisLifetime);
  }

  void _decayTimers(double dt) {
    if (state.perfectFlashTimer > 0) state.perfectFlashTimer -= dt;
    if (state.dropBounceTimer > 0) state.dropBounceTimer -= dt;
    if (state.impactShakeTimer > 0) state.impactShakeTimer -= dt;
  }
}
