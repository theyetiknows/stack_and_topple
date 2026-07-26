import 'package:flutter_test/flutter_test.dart';
import 'package:stack_and_topple/core/custom_stability_model.dart';
import 'package:stack_and_topple/core/game_loop.dart';
import 'package:stack_and_topple/core/game_state.dart';
import 'package:stack_and_topple/core/input/input_event.dart';
import 'package:stack_and_topple/core/tuning.dart';

GameLoop _newRun([TuningConfig? tuning]) {
  final state = GameState(tuning ?? const TuningConfig());
  final loop = GameLoop(state: state, stability: CustomStabilityModel());
  loop.startRun();
  return loop;
}

/// Stack [n] perfect drops so there is a tower to knock over.
void _stack(GameLoop loop, int n) {
  final s = loop.state;
  for (var i = 0; i < n; i++) {
    s.pieceCenterX = s.top.centerX;
    loop.tick(1 / 120, const [DropEvent()]);
  }
}

void main() {
  group('drop resolution', () {
    test('perfect drop keeps platform width, no lean, no debris', () {
      final loop = _newRun();
      final s = loop.state;
      final w0 = s.top.width;
      s.pieceCenterX = s.top.centerX; // perfectly aligned
      loop.tick(1 / 120, const [DropEvent()]);

      expect(s.blocksPlaced, 1);
      expect(s.top.width, closeTo(w0, 1e-9));
      expect(s.leanLateralVel, 0);
      expect(s.leanLateral, 0);
      expect(s.lastDropPerfect, isTrue);
      expect(s.perfectDrops, 1);
      expect(s.debris, isEmpty);
      expect(s.score, 1 + s.tuning.perfectBonus);
    });

    test('misaligned drop slices to the exact overlap and spawns debris', () {
      final loop = _newRun();
      final s = loop.state;
      final w0 = s.top.width;
      const off = 0.5; // beyond perfectTolerance
      s.pieceCenterX = s.top.centerX + off;
      final pieceW = s.pieceWidth;
      loop.tick(1 / 120, const [DropEvent()]);

      expect(s.blocksPlaced, 1);
      // The kept part is EXACTLY the overlap — the cut lines up with the drop.
      expect(s.top.width, closeTo(w0 - off, 1e-9));
      expect(s.top.right, closeTo(w0 / 2, 1e-9)); // flush with old right edge
      // The overhang broke off as debris; kept + debris == the dropped piece.
      expect(s.debris, hasLength(1));
      expect(s.debris.single.width, closeTo(off, 1e-9));
      expect(s.top.width + s.debris.single.width, closeTo(pieceW, 1e-9));
      expect(s.leanLateralVel, greaterThan(0)); // kicked toward +x
      expect(s.lastDropPerfect, isFalse);
      expect(s.score, 1);
    });

    test('debris lands on the ground and settles instead of falling forever',
        () {
      final loop = _newRun();
      final s = loop.state;
      s.pieceCenterX = s.top.centerX + 0.5;
      loop.tick(1 / 120, const [DropEvent()]);
      final d = s.debris.single;

      // Simulate until it reaches the floor and stops bouncing.
      for (var i = 0; i < 400; i++) {
        loop.tick(1 / 120, const []);
      }
      expect(d.bottomY, greaterThanOrEqualTo(0)); // never sinks underground
      expect(d.vy, 0); // settled

      for (var i = 0; i < 1000 && s.debris.isNotEmpty; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.debris, isEmpty); // culled by lifetime after settling
    });

    test('total miss: piece falls as debris, brief beat, then game over', () {
      final loop = _newRun();
      final s = loop.state;
      final pieceW = s.pieceWidth;
      s.pieceCenterX = s.top.right + s.pieceWidth; // no overlap at all
      loop.tick(1 / 120, const [DropEvent()]);

      expect(s.phase, GamePhase.ending); // watch-it-fall beat
      expect(s.debris, hasLength(1));
      expect(s.debris.single.width, closeTo(pieceW, 1e-9));
      expect(s.blocksPlaced, 0); // a miss places nothing

      for (var i = 0; i < 1000 && s.phase == GamePhase.ending; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.phase, GamePhase.gameOver);
    });
  });

  group('difficulty ramp & level bonus', () {
    test('sweep speed takes a chunky step at each level boundary', () {
      final s = GameState(const TuningConfig());
      final t = s.tuning;

      s.blocksPlaced = t.levelSize - 1; // last block of level 0
      final beforeStep = s.currentSweepSpeed;
      s.blocksPlaced = t.levelSize; // first block of level 1
      final afterStep = s.currentSweepSpeed;

      expect(s.level, 1);
      expect(
        afterStep - beforeStep,
        closeTo(t.sweepSpeedPerLevel + t.sweepSpeedPerBlock, 1e-9),
      );
      expect(afterStep, lessThanOrEqualTo(t.maxSweepSpeed));
    });

    test('reaching a level awards its one-time bonus', () {
      final loop = _newRun();
      final s = loop.state;
      final t = s.tuning;
      _stack(loop, t.levelSize); // exactly crosses into level 1
      expect(s.level, 1);
      // levelSize perfect drops + the level bonus, exactly once.
      expect(s.score, t.levelSize * (1 + t.perfectBonus) + t.levelBonus);
    });

    test('sweep speed is capped', () {
      final s = GameState(const TuningConfig());
      s.blocksPlaced = 10000;
      expect(s.currentSweepSpeed, s.tuning.maxSweepSpeed);
    });
  });

  group('collapse (classic mode)', () {
    test('crossing the threshold breaks the tower into a ground jumble', () {
      final loop = _newRun();
      final s = loop.state;
      _stack(loop, 5);
      final aboveBase = s.tower.length - 1;
      final scoreBefore = s.score;

      s.leanLateral = s.tuning.toppleThreshold + 0.1;
      loop.tick(1 / 120, const []);

      expect(s.phase, GamePhase.toppling);
      expect(s.tower, hasLength(1)); // only the base survives
      expect(s.debris.length, aboveBase); // every block tumbles individually
      expect(s.leanLateral, 0); // base sits flat — no spinning tower
      expect(s.score, scoreBefore); // terminal collapse keeps the score

      for (var i = 0; i < 2000 && s.phase == GamePhase.toppling; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.phase, GamePhase.gameOver);
    });

    test('classic mode never enters the save window', () {
      final loop = _newRun();
      final s = loop.state;
      _stack(loop, 6);
      s.leanLateral = s.tuning.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.toppling); // straight to collapse
    });
  });

  group('balance mode saves', () {
    test('instability sheds top blocks and opens the SAVE window', () {
      final loop = _newRun();
      final s = loop.state;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);
      final heightBefore = s.tower.length; // 5 (base + 4)
      final scoreBefore = s.score;

      s.leanLateral = s.tuning.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);

      expect(s.phase, GamePhase.critical);
      expect(s.tower.length, lessThan(heightBefore)); // top shed
      expect(s.debris, isNotEmpty); // shed blocks tumble
      expect(s.score, lessThan(scoreBefore)); // fallen-block penalty
      expect(s.blocksPlaced, s.tower.length - 1); // height bookkeeping
      // Lean clamped back inside the threshold, still critical.
      expect(s.leanMagnitude, lessThan(s.tuning.toppleThreshold));
    });

    test('levelling the phone within the window SAVES the run', () {
      final loop = _newRun();
      final s = loop.state;
      final t = s.tuning;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);
      final scoreBefore = s.score;

      s.leanLateral = t.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.critical);
      final shedPenalty = scoreBefore - s.score;
      expect(shedPenalty, greaterThan(0));

      // Player levels the phone: neutral balance → weak spring recovers.
      var ticks = 0;
      while (s.phase == GamePhase.critical && ticks < 600) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput())]);
        ticks++;
      }
      expect(s.phase, GamePhase.sweeping); // SAVED — run continues, lower
      expect(s.saves, 1);
      expect(s.score, scoreBefore - shedPenalty + t.saveBonus);
    });

    test('holding an adverse tilt cannot re-tip mid-window; it collapses only '
        'when the window expires', () {
      final loop = _newRun();
      final s = loop.state;
      final t = s.tuning;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);

      s.leanLateral = t.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.critical);

      // Half the window elapses under a hard adverse tilt: the soft wall
      // holds the tower just inside the threshold — still saveable.
      final halfWindow = (t.saveWindow * 120 * 0.5).floor();
      for (var i = 0; i < halfWindow; i++) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
      }
      expect(s.phase, GamePhase.critical);
      expect(s.leanMagnitude, lessThanOrEqualTo(t.toppleThreshold));

      // Kept up until expiry, the run ends in the full jumble.
      var ticks = 0;
      while (s.phase == GamePhase.critical && ticks < 2000) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
        ticks++;
      }
      expect(s.phase, GamePhase.toppling);
      expect(s.tower, hasLength(1)); // full jumble
    });

    test('panic overcorrection is survivable: the swing to the far side does '
        'not collapse, and steadying afterwards still saves', () {
      final loop = _newRun();
      final s = loop.state;
      final t = s.tuning;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);

      s.leanLateral = t.toppleThreshold + 0.05; // tipping right
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.critical);

      // Panic: yank hard LEFT for 0.5 s. The lean swings through centre to
      // the far wall — under the old rules this was an instant collapse.
      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: -1.0))]);
      }
      expect(s.phase, GamePhase.critical); // survived the overcorrection

      // Now steady the phone: dwell in the safe zone completes the save.
      var ticks = 0;
      while (s.phase == GamePhase.critical && ticks < 600) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput())]);
        ticks++;
      }
      expect(s.phase, GamePhase.sweeping);
      expect(s.saves, 1);
    });

    test('doing nothing lets the window expire into a collapse', () {
      // Zero-stiffness spring: the lean neither recovers nor grows, so ONLY
      // the window timer can end the critical phase.
      const frozen = TuningConfig(
        restoringStiffness: 0,
        wobbleDamping: 0,
      );
      final loop = _newRun(frozen);
      final s = loop.state;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);

      s.leanLateral = frozen.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.critical);

      final windowTicks = (frozen.saveWindow * 120).ceil() + 5;
      for (var i = 0; i < windowTicks; i++) {
        loop.tick(1 / 120, const []);
      }
      expect(s.phase, GamePhase.toppling); // time ran out
    });
  });

  group('loose stack', () {
    /// A Loose Stack run with [n] perfectly-aligned blocks placed.
    GameLoop looseRun([int n = 6]) {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      _stack(loop, n);
      return loop;
    }

    test('requires Balance Mode: the flag is inert on a classic run', () {
      final loop = _newRun();
      loop.startRun(looseStack: true); // no balanceMode
      expect(loop.state.looseStackActive, isFalse);
    });

    test('below the slip angle nothing slides', () {
      final loop = looseRun();
      final s = loop.state;
      final before = s.tower.map((b) => b.centerX).toList();

      // Well inside every interface's grip.
      s.leanLateral = s.tuning.slipAngle * 0.5;
      for (var i = 0; i < 240; i++) {
        loop.tick(1 / 120, const []);
        s.leanLateral = s.tuning.slipAngle * 0.5; // hold it there
      }
      for (var i = 0; i < s.tower.length; i++) {
        expect(s.tower[i].centerX, closeTo(before[i], 1e-9));
      }
    });

    test('past the slip angle the stack shears from the top down', () {
      final loop = looseRun();
      final s = loop.state;
      final before = s.tower.map((b) => b.centerX).toList();

      // Enough to overcome the top interfaces but not the deep ones: grip
      // grows by gripPerBlockAbove per block of load, so target a lean that
      // only the upper few interfaces can lose.
      final partial =
          s.tuning.slipAngle + s.tuning.gripPerBlockAbove * 2.5;
      for (var i = 0; i < 60; i++) {
        s.leanLateral = partial;
        loop.tick(1 / 120, const []);
      }

      final n = s.tower.length;
      final topShift = (s.tower[n - 1].centerX - before[n - 1]).abs();
      final lowShift = (s.tower[1].centerX - before[1]).abs();
      expect(topShift, greaterThan(0)); // the top slid
      expect(topShift, greaterThan(lowShift)); // more than anything beneath
      expect(s.tower.first.centerX, closeTo(before.first, 1e-9)); // base pinned
      expect(s.phase, GamePhase.sweeping); // erosion, not a topple
    });

    test('slides carry: displacement never decreases going up the stack', () {
      final loop = looseRun();
      final s = loop.state;
      final before = s.tower.map((b) => b.centerX).toList();

      for (var i = 0; i < 60; i++) {
        s.leanLateral = s.tuning.slipAngle + s.tuning.gripPerBlockAbove * 3;
        loop.tick(1 / 120, const []);
      }

      // Each block is carried by every slide beneath it, so shear accumulates
      // monotonically upward.
      var prev = 0.0;
      for (var i = 0; i < s.tower.length; i++) {
        final shift = (s.tower[i].centerX - before[i]).abs();
        expect(shift, greaterThanOrEqualTo(prev - 1e-9));
        prev = shift;
      }
    });

    test('a block that loses its footing falls WITH everything above it', () {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      final s = loop.state;
      _stack(loop, 5);
      final scoreBefore = s.score;

      // Shove a mid-stack block almost clear of its support; the blocks above
      // it are still aligned, but they are about to lose their floor.
      final victim = s.tower[2];
      final below = s.tower[1];
      victim.centerX = below.centerX + below.width;
      final expectedLost = s.tower.length - 2;

      loop.tick(1 / 120, const []);

      expect(s.tower.length, 2); // base + the one block below the failure
      expect(s.blocksLost, expectedLost);
      expect(s.debris.length, greaterThanOrEqualTo(expectedLost));
      expect(
        s.score,
        scoreBefore - s.tuning.fallenBlockPenalty * expectedLost,
      );
      expect(s.blocksPlaced, s.tower.length - 1);
    });

    test('shearing down to the bare base ends the run', () {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      final s = loop.state;
      _stack(loop, 3);

      // Knock the first stacked block clear: everything above goes with it.
      s.tower[1].centerX = s.tower[0].centerX + s.tower[0].width * 2;
      loop.tick(1 / 120, const []);

      expect(s.tower, hasLength(1)); // stripped to the base
      expect(s.phase, GamePhase.toppling); // wreckage beat, then game over
      for (var i = 0; i < 2000 && s.phase == GamePhase.toppling; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.phase, GamePhase.gameOver);
    });

    test('erode-only: a hard sustained lean never opens a SAVE window', () {
      final loop = looseRun(8);
      final s = loop.state;

      var sawCritical = false;
      for (var i = 0; i < 1200; i++) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
        if (s.phase == GamePhase.critical) sawCritical = true;
        if (s.phase == GamePhase.gameOver) break;
      }
      expect(sawCritical, isFalse); // no binary topple/save in this mode
      // Loose Stack is walled at its OWN (much wider) angle, not the topple
      // threshold — the tower leans hard and sheds instead of tipping.
      expect(
        s.leanMagnitude,
        lessThanOrEqualTo(s.tuning.looseLeanWall + 1e-9),
      );
      expect(s.blocksLost, greaterThan(0)); // damage arrived as erosion
    });

    test('the sweep follows a sheared tower so the top stays reachable', () {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      final s = loop.state;
      _stack(loop, 5);

      // Shear the stack sideways: hold a moderate lean only until the tower
      // has visibly drifted, so the test states its intent ("drifted, still
      // standing") rather than encoding a tick count that every friction
      // retune invalidates.
      final lean = s.tuning.slipAngle + s.tuning.gripPerBlockAbove * 2;
      for (var i = 0; i < 1200 && s.top.centerX.abs() < 0.5; i++) {
        s.leanLateral = lean;
        loop.tick(1 / 120, const []);
      }
      expect(s.tower.length, greaterThan(2)); // survived to be stacked on
      final topX = s.top.centerX;
      expect(topX.abs(), greaterThan(0.3)); // it really did drift

      // The next spawn re-centres the sweep on the drifted top block, so the
      // piece can still be brought fully over it.
      s.pieceCenterX = s.top.centerX;
      loop.tick(1 / 120, const [DropEvent()]);

      // The sweep re-centred on the drifted tower rather than the origin
      // (blocks keep sliding after the spawn, hence the tolerance).
      expect(s.sweepCenterX, closeTo(topX, 0.05));
      expect(s.sweepCenterX.abs(), greaterThan(0.3));
      // ...and the piece still enters a full sweep-range away from that
      // centre (minus the one sub-step it already travelled this tick).
      expect(
        (s.pieceCenterX - s.sweepCenterX).abs(),
        closeTo(s.tuning.sweepHalfRange, 0.1),
      );
    });

    test('an overhanging section falls once its centre of mass leaves support',
        () {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      final s = loop.state;
      _stack(loop, 4);

      // Shift the top two blocks far enough that the section above block 2
      // has its combined centre of mass past the contact patch, even though
      // each individual block still overlaps its neighbour.
      final support = s.tower[2];
      for (var i = 3; i < s.tower.length; i++) {
        s.tower[i].centerX = support.centerX + support.width * 0.9;
      }
      loop.tick(1 / 120, const []);

      expect(s.tower.length, lessThan(5)); // the overhang went
      expect(s.blocksLost, greaterThan(0));
    });

    test('at the full 45° wall every interface slips but the base never moves',
        () {
      final loop = _newRun();
      loop.startRun(balanceMode: true, looseStack: true);
      final s = loop.state;
      _stack(loop, 6);
      final before = s.tower.map((b) => b.centerX).toList();
      final baseX = s.tower.first.centerX;

      // One tick at the wall, before anything has had time to shear off.
      s.leanLateral = s.tuning.looseLeanWall;
      loop.tick(1 / 120, const []);

      for (var i = 1; i < s.tower.length; i++) {
        expect(
          s.tower[i].centerX,
          isNot(closeTo(before[i], 1e-9)),
          reason: 'interface $i should slip at the 45° wall',
        );
      }
      expect(s.tower.first.centerX, closeTo(baseX, 1e-9)); // base is planted
    });

    test('sticky mode is unchanged: no sliding, save window still opens', () {
      final loop = _newRun();
      loop.startRun(balanceMode: true); // looseStack off
      final s = loop.state;
      _stack(loop, 4);
      final before = s.tower.map((b) => b.centerX).toList();

      s.leanLateral = s.tuning.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);

      expect(s.phase, GamePhase.critical); // classic shed + SAVE path
      for (var i = 0; i < s.tower.length; i++) {
        expect(s.tower[i].centerX, closeTo(before[i], 1e-9)); // welded
      }
    });
  });

  group('seeded spawn sides', () {
    List<int> sidesFor(int seed) {
      final loop = _newRun();
      loop.startRun(seed: seed);
      final s = loop.state;
      final out = <int>[];
      for (var i = 0; i < 12; i++) {
        out.add(s.sweepDir);
        s.pieceCenterX = s.top.centerX;
        loop.tick(1 / 120, const [DropEvent()]);
      }
      return out;
    }

    test('classic runs keep the sweep centred on the origin', () {
      final loop = _newRun();
      loop.startRun(seed: 7);
      expect(loop.state.sweepCenterX, 0);
    });

    test('pieces enter from both sides, at the matching edge', () {
      final loop = _newRun();
      loop.startRun(seed: 42);
      final s = loop.state;
      final seen = <int>{};
      for (var i = 0; i < 12; i++) {
        seen.add(s.sweepDir);
        // The piece enters from the edge OPPOSITE its direction of travel
        // (near the edge: the spawning tick already advanced one sub-step).
        expect(s.pieceCenterX * s.sweepDir, lessThan(0));
        expect(
          s.pieceCenterX.abs(),
          greaterThan(s.tuning.sweepHalfRange - 0.2),
        );
        s.pieceCenterX = s.top.centerX;
        loop.tick(1 / 120, const [DropEvent()]);
      }
      expect(seen, {1, -1}); // both directions occur
    });

    test('same seed → same side sequence; different seed → different', () {
      expect(sidesFor(42), equals(sidesFor(42)));
      expect(sidesFor(42), isNot(equals(sidesFor(1337))));
    });
  });

  test('identical scripted input is deterministic', () {
    List<double> run() {
      final loop = _newRun();
      final s = loop.state;
      for (var i = 0; i < 600; i++) {
        final events =
            (i % 40 == 0) ? const [DropEvent()] : const <InputEvent>[];
        loop.tick(1 / 120, events);
      }
      return [
        s.score.toDouble(),
        s.tower.length.toDouble(),
        s.debris.length.toDouble(),
        s.leanLateral,
      ];
    }

    expect(run(), equals(run()));
  });
}
