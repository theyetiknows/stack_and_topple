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

    test('debris falls under gravity and is culled after its lifetime', () {
      final loop = _newRun();
      final s = loop.state;
      s.pieceCenterX = s.top.centerX + 0.5;
      loop.tick(1 / 120, const [DropEvent()]);
      final d = s.debris.single;
      final y0 = d.bottomY;

      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 120, const []);
      }
      expect(d.bottomY, lessThan(y0)); // falling (world Y is up)

      for (var i = 0; i < 1000 && s.debris.isNotEmpty; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.debris, isEmpty); // culled by lifetime
    });

    test('total miss: piece falls as debris, brief beat, then game over', () {
      final loop = _newRun();
      final s = loop.state;
      final pieceW = s.pieceWidth;
      s.pieceCenterX = s.top.right + s.pieceWidth; // no overlap at all
      loop.tick(1 / 120, const [DropEvent()]);

      expect(s.phase, GamePhase.ending); // watch-it-fall beat, not a topple
      expect(s.debris, hasLength(1));
      expect(s.debris.single.width, closeTo(pieceW, 1e-9));
      expect(s.blocksPlaced, 0); // a miss places nothing

      for (var i = 0; i < 1000 && s.phase == GamePhase.ending; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.phase, GamePhase.gameOver);
    });
  });

  group('difficulty ramp', () {
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

    test('sweep speed is capped', () {
      final s = GameState(const TuningConfig());
      s.blocksPlaced = 10000;
      expect(s.currentSweepSpeed, s.tuning.maxSweepSpeed);
    });
  });

  group('stability', () {
    test('lean beyond threshold topples', () {
      final loop = _newRun();
      final s = loop.state;
      s.leanLateral = s.tuning.toppleThreshold + 0.1;
      loop.tick(1 / 120, const []);
      expect(s.phase, GamePhase.toppling);
    });

    test('small wobble recovers toward upright without toppling', () {
      final loop = _newRun();
      final s = loop.state;
      s.leanLateral = 0.05;
      final start = s.leanLateral.abs();
      for (var i = 0; i < 240 && s.phase == GamePhase.sweeping; i++) {
        loop.tick(1 / 120, const []);
      }
      expect(s.phase, GamePhase.sweeping);
      expect(s.leanLateral.abs(), lessThan(start));
    });
  });

  group('balance mode wiring', () {
    test('balance input is HELD between events (sensor slower than sim)', () {
      final loop = _newRun();
      final s = loop.state;
      loop.startRun(balanceMode: true);
      loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
      final v1 = s.leanLateralVel;
      expect(v1, greaterThan(0));
      for (var i = 0; i < 10; i++) {
        loop.tick(1 / 120, const []); // no new events
      }
      expect(s.currentRoll, 1.0); // still held
      expect(s.leanLateral, greaterThan(0)); // force kept integrating
    });

    test('classic runs ignore balance events entirely', () {
      final loop = _newRun(); // startRun() default: balanceMode false
      final s = loop.state;
      for (var i = 0; i < 60; i++) {
        loop.tick(1 / 120, const [BalanceEvent(BalanceInput(roll: 1.0))]);
      }
      expect(s.leanLateral, 0);
      expect(s.leanDepth, 0);
      expect(s.phase, GamePhase.sweeping);
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
