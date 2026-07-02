import 'block.dart';
import 'tuning.dart';

/// The lifecycle of a single run.
enum GamePhase {
  /// Before the first run / on the start screen.
  ready,

  /// A piece is sweeping and can be dropped.
  sweeping,

  /// The tower is falling over (topple animation), run about to end.
  toppling,

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

  // --- Active sweeping piece ---------------------------------------------------
  /// World-space X of the sweeping piece's centre.
  double pieceCenterX = 0;

  /// +1 sweeping right, -1 sweeping left.
  int sweepDir = 1;

  // --- Lean physics (radians) --------------------------------------------------
  double leanLateral = 0; // Lx
  double leanLateralVel = 0;
  double leanDepth = 0; // Lz — dormant until Balance Mode
  double leanDepthVel = 0;

  // --- Run bookkeeping ---------------------------------------------------------
  GamePhase phase = GamePhase.ready;
  int score = 0;
  int blocksPlaced = 0;

  /// True if the most recent drop was perfect (for feedback/juice).
  bool lastDropPerfect = false;

  // --- Topple animation --------------------------------------------------------
  double toppleTimer = 0;
  int toppleDir = 1;

  // --- Derived helpers ---------------------------------------------------------
  Block get top => tower.last;

  /// The sweeping piece inherits the width of the current top surface.
  double get pieceWidth =>
      tower.isEmpty ? tuning.initialBlockWidth : tower.last.width;

  double get pieceLeft => pieceCenterX - pieceWidth / 2;
  double get pieceRight => pieceCenterX + pieceWidth / 2;

  bool get isPlaying => phase == GamePhase.sweeping;
}
