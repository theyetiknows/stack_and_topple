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
    test('perfect drop keeps platform width and adds no lean', () {
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
      expect(s.score, 1 + s.tuning.perfectBonus);
    });

    test('misaligned drop shrinks the platform and kicks the lean', () {
      final loop = _newRun();
      final s = loop.state;
      final w0 = s.top.width;
      s.pieceCenterX = s.top.centerX + 0.5; // beyond perfectTolerance
      loop.tick(1 / 120, const [DropEvent()]);

      expect(s.blocksPlaced, 1);
      expect(s.top.width, lessThan(w0));
      expect(s.leanLateralVel, greaterThan(0)); // kicked toward +x
      expect(s.lastDropPerfect, isFalse);
      expect(s.score, 1);
    });

    test('total miss ends the run', () {
      final loop = _newRun();
      final s = loop.state;
      s.pieceCenterX = s.top.right + s.pieceWidth; // no overlap at all
      loop.tick(1 / 120, const [DropEvent()]);
      expect(s.phase, GamePhase.toppling);

      for (var i = 0; i < 1000 && s.phase == GamePhase.toppling; i++) {
        loop.tick(1 / 60, const []);
      }
      expect(s.phase, GamePhase.gameOver);
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

  test('identical scripted input is deterministic', () {
    List<double> run() {
      final loop = _newRun();
      final s = loop.state;
      for (var i = 0; i < 600; i++) {
        final events =
            (i % 40 == 0) ? const [DropEvent()] : const <InputEvent>[];
        loop.tick(1 / 120, events);
      }
      return [s.score.toDouble(), s.tower.length.toDouble(), s.leanLateral];
    }

    expect(run(), equals(run()));
  });
}
