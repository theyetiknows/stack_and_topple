import 'dart:math' as math;

import 'block.dart';
import 'debris.dart';
import 'tuning.dart';

/// The lifecycle of a single run.
enum GamePhase {
  /// Before the first run / on the start screen.
  ready,

  /// A piece is sweeping and can be dropped.
  sweeping,

  /// Balance Mode caught a topple: top blocks shed, brief SAVE window —
  /// steady the tower to continue from the lower height.
  critical,

  /// The tower is breaking apart (per-block jumble), run about to end.
  toppling,

  /// The piece missed entirely: brief beat while it falls, then game over.
  ending,

  /// Run finished; show score + share.
  gameOver,
}

/// The single source of truth for a run.
///
/// Deliberately a plain mutable object advanced in place by [GameLoop]; this
/// keeps per-frame allocation at zero. Determinism comes from the update logic
/// being pure w.r.t. (dt, events), not from immutability. Fields are public so
/// tests can set up precise scenarios.
class GameState {
  GameState(this.tuning);

  final TuningConfig tuning;

  /// Placed blocks, base first. `tower.last` is the current support surface.
  final List<Block> tower = [];

  /// Sliced-off overhangs / missed pieces currently tumbling (cosmetic only).
  final List<Debris> debris = [];

  // --- Active sweeping piece ---------------------------------------------------
  /// World-space X of the sweeping piece's centre.
  double pieceCenterX = 0;

  /// +1 sweeping right, -1 sweeping left.
  int sweepDir = 1;

  // --- Lean physics (radians) --------------------------------------------------
  double leanLateral = 0; // Lx
  double leanLateralVel = 0;
  double leanDepth = 0; // Lz — driven only while Balance Mode is active
  double leanDepthVel = 0;

  // --- Balance Mode ------------------------------------------------------------
  /// Whether this run was started with Balance Mode (tilt) engaged.
  bool balanceModeActive = false;

  /// Latest processed tilt input, HELD between sensor events (sensors emit at
  /// ~50 Hz while the sim ticks at 120 Hz — snapping to zero between events
  /// would turn tilt into jitter). Normalised to roughly [-1, 1].
  double currentRoll = 0;
  double currentPitch = 0;

  // --- Run bookkeeping ---------------------------------------------------------
  GamePhase phase = GamePhase.ready;
  int score = 0;
  int blocksPlaced = 0;

  /// Count of perfect drops this run (also drives the PERFECT flash in the HUD).
  int perfectDrops = 0;

  /// True if the most recent drop was perfect (for feedback/juice).
  bool lastDropPerfect = false;

  // --- Effect timers (count down to 0; presentation reads them for juice) ------
  double perfectFlashTimer = 0;
  double dropBounceTimer = 0;
  double impactShakeTimer = 0;

  // --- Collapse / save / ending --------------------------------------------------
  /// Elapsed time of the collapse jumble (GamePhase.toppling).
  double collapseTimer = 0;

  /// Remaining time in the SAVE window (GamePhase.critical).
  double saveWindowTimer = 0;

  /// Successful Balance-Mode saves this run (drives the SAVED! flash).
  int saves = 0;

  /// Highest level already granted its one-time bonus this run.
  int highestLevelAwarded = 0;

  /// Countdown used by [GamePhase.ending] (watch-the-miss-fall beat).
  double endTimer = 0;

  // --- Derived helpers ---------------------------------------------------------
  Block get top => tower.last;

  /// The sweeping piece inherits the width of the current top surface.
  double get pieceWidth =>
      tower.isEmpty ? tuning.initialBlockWidth : tower.last.width;

  double get pieceLeft => pieceCenterX - pieceWidth / 2;
  double get pieceRight => pieceCenterX + pieceWidth / 2;

  bool get isPlaying => phase == GamePhase.sweeping;

  /// Radial lean magnitude ‖(Lx, Lz)‖ — the quantity tested against
  /// [TuningConfig.toppleThreshold]. Equals |Lx| when Balance Mode is off.
  double get leanMagnitude =>
      math.sqrt(leanLateral * leanLateral + leanDepth * leanDepth);

  /// Difficulty tier: steps up every [TuningConfig.levelSize] placed blocks.
  int get level => blocksPlaced ~/ tuning.levelSize;

  /// Sweep speed for the current height: base + smooth per-block creep + a
  /// chunky per-level step, capped so it stays humanly tappable.
  double get currentSweepSpeed => math.min(
        tuning.baseSweepSpeed +
            tuning.sweepSpeedPerBlock * blocksPlaced +
            tuning.sweepSpeedPerLevel * level,
        tuning.maxSweepSpeed,
      );
}
