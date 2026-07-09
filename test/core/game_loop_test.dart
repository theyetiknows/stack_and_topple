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

    test('holding a hard adverse tilt re-tips into a full collapse', () {
      final loop = _newRun();
      final s = loop.state;
      loop.startRun(balanceMode: true);
      _stack(loop, 4);

      s.leanLateral = s.tuning.toppleThreshold + 0.05;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.critical);

      // Player keeps tilting hard the wrong way: equilibrium sits past the
      // threshold, so the lean is dragged back over the line.
      var ticks = 0;
      while (s.phase == GamePhase.critical && ticks < 2000) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
        ticks++;
      }
      expect(s.phase, GamePhase.toppling);
      expect(s.tower, hasLength(1)); // full jumble
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
